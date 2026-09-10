-- Public launch: pending registration cancellation + automatic seat release/repricing.
--
-- Rules:
--   1. Student may cancel only their own active full-term registration while order is pending
--      AND before any payment information has been submitted.
--   2. Admin may cancel an active registration while the order is still pending.
--   3. Cancellation never deletes transaction rows. registrations.status becomes cancelled.
--   4. Capacity is derived from active registrations, so changing status to cancelled releases
--      the seat immediately.
--   5. The order is repriced from remaining active registrations. The existing 2+ full-term
--      discount setting is recalculated by term. If none remain, order status becomes cancelled
--      and amount becomes 0.

CREATE OR REPLACE FUNCTION public.fn_recalculate_order_amount(
  p_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_enabled boolean := true;
  v_min_classes integer := 2;
  v_discount_percent numeric(5,2) := 96.00;
  v_active_count integer := 0;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2) := 0;
BEGIN
  SELECT enabled, min_full_term_classes, full_term_discount_percent
  INTO v_enabled, v_min_classes, v_discount_percent
  FROM public.registration_settings
  WHERE id = 1;

  SELECT COUNT(*)::int
  INTO v_active_count
  FROM public.registrations r
  WHERE r.order_id = p_order_id
    AND r.status = 'active';

  IF v_active_count = 0 THEN
    UPDATE public.orders
    SET status = 'cancelled',
        subtotal_amount = 0,
        total_amount = 0
    WHERE id = p_order_id;

    RETURN;
  END IF;

  WITH active_term_counts AS (
    SELECT r.term_id, COUNT(*)::int AS class_count
    FROM public.registrations r
    WHERE r.order_id = p_order_id
      AND r.status = 'active'
      AND r.registration_type = 'full_term'
    GROUP BY r.term_id
  )
  SELECT
    COALESCE(SUM(c.full_term_price), 0),
    ROUND(
      COALESCE(
        SUM(
          c.full_term_price * CASE
            WHEN v_enabled AND tc.class_count >= v_min_classes
              THEN v_discount_percent / 100.0
            ELSE 1
          END
        ),
        0
      ),
      0
    )
  INTO v_subtotal, v_total
  FROM public.registrations r
  JOIN public.classes c ON c.id = r.class_id
  JOIN active_term_counts tc ON tc.term_id = r.term_id
  WHERE r.order_id = p_order_id
    AND r.status = 'active'
    AND r.registration_type = 'full_term';

  UPDATE public.orders
  SET status = 'confirmed',
      subtotal_amount = v_subtotal,
      total_amount = v_total
  WHERE id = p_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_recalculate_order_amount(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_recalculate_order_amount(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.fn_recalculate_order_amount(uuid) FROM authenticated;


CREATE OR REPLACE FUNCTION public.rpc_cancel_my_pending_registration(
  p_registration_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_id uuid := auth.uid();
  v_registration public.registrations%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_total numeric(10,2);
  v_order_status text;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION '必須登入才能取消報名' USING ERRCODE = '28000';
  END IF;

  SELECT *
  INTO v_registration
  FROM public.registrations
  WHERE id = p_registration_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'registration_not_found';
  END IF;

  IF v_registration.student_id <> v_student_id THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = v_registration.order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_registration.status <> 'active' THEN
    RAISE EXCEPTION 'registration_not_active';
  END IF;

  IF v_registration.registration_type <> 'full_term' THEN
    RAISE EXCEPTION 'unsupported_registration_type';
  END IF;

  IF v_order.payment_status <> 'pending' OR v_order.status <> 'confirmed' THEN
    RAISE EXCEPTION 'cannot_cancel_after_payment';
  END IF;

  -- Once a student has told the system they paid (bank reference or LINE Pay), do not let
  -- them self-cancel while the teacher may be reconciling the payment. Admin can still act.
  IF v_order.payment_method IS NOT NULL OR v_order.payment_reference IS NOT NULL THEN
    RAISE EXCEPTION 'payment_info_already_submitted';
  END IF;

  UPDATE public.registrations
  SET status = 'cancelled',
      cancelled_at = now(),
      cancelled_reason = 'student_cancelled_before_payment'
  WHERE id = p_registration_id;

  INSERT INTO public.audit_logs (
    actor_id, actor_role, action, entity_type, entity_id, after_data
  ) VALUES (
    v_student_id,
    'student',
    'registration_cancel',
    'registrations',
    p_registration_id,
    jsonb_build_object(
      'order_id', v_registration.order_id,
      'class_id', v_registration.class_id,
      'status', 'cancelled',
      'reason', 'student_cancelled_before_payment'
    )
  );

  PERFORM public.fn_recalculate_order_amount(v_registration.order_id);

  SELECT total_amount, status
  INTO v_total, v_order_status
  FROM public.orders
  WHERE id = v_registration.order_id;

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', p_registration_id,
    'order_id', v_registration.order_id,
    'order_status', v_order_status,
    'total_amount', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_cancel_my_pending_registration(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_cancel_my_pending_registration(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_my_pending_registration(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.rpc_admin_cancel_pending_registration(
  p_registration_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_registration public.registrations%ROWTYPE;
  v_order public.orders%ROWTYPE;
  v_total numeric(10,2);
  v_order_status text;
BEGIN
  IF v_admin_id IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_registration
  FROM public.registrations
  WHERE id = p_registration_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'registration_not_found';
  END IF;

  SELECT *
  INTO v_order
  FROM public.orders
  WHERE id = v_registration.order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_registration.status <> 'active' THEN
    RAISE EXCEPTION 'registration_not_active';
  END IF;

  IF v_registration.registration_type <> 'full_term' THEN
    RAISE EXCEPTION 'unsupported_registration_type';
  END IF;

  IF v_order.payment_status <> 'pending' OR v_order.status <> 'confirmed' THEN
    RAISE EXCEPTION 'cannot_cancel_after_payment';
  END IF;

  UPDATE public.registrations
  SET status = 'cancelled',
      cancelled_at = now(),
      cancelled_reason = 'admin_cancelled_before_payment'
  WHERE id = p_registration_id;

  INSERT INTO public.audit_logs (
    actor_id, actor_role, action, entity_type, entity_id, after_data
  ) VALUES (
    v_admin_id,
    'admin',
    'registration_cancel',
    'registrations',
    p_registration_id,
    jsonb_build_object(
      'student_id', v_registration.student_id,
      'order_id', v_registration.order_id,
      'class_id', v_registration.class_id,
      'status', 'cancelled',
      'reason', 'admin_cancelled_before_payment'
    )
  );

  PERFORM public.fn_recalculate_order_amount(v_registration.order_id);

  SELECT total_amount, status
  INTO v_total, v_order_status
  FROM public.orders
  WHERE id = v_registration.order_id;

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', p_registration_id,
    'order_id', v_registration.order_id,
    'order_status', v_order_status,
    'total_amount', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_cancel_pending_registration(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rpc_admin_cancel_pending_registration(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_cancel_pending_registration(uuid) TO authenticated;

COMMENT ON FUNCTION public.rpc_cancel_my_pending_registration(uuid) IS
  '學生取消自己的待付款期課報名；若已提交付款資訊則必須由 Admin 處理。取消後立即釋放名額並重算訂單與多堂優惠。';

COMMENT ON FUNCTION public.rpc_admin_cancel_pending_registration(uuid) IS
  'Admin 取消尚未確認收款的有效期課報名；取消後立即釋放名額並重算訂單與多堂優惠。';
