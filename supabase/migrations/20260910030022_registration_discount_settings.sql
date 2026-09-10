-- Prelaunch registration settings and multi-class full-term discount.
-- Default: 2 or more full-term classes in the same term receive 96% pricing.

CREATE TABLE public.registration_settings (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  enabled boolean NOT NULL DEFAULT true,
  min_full_term_classes integer NOT NULL DEFAULT 2 CHECK (min_full_term_classes >= 2),
  full_term_discount_percent numeric(5,2) NOT NULL DEFAULT 96.00
    CHECK (full_term_discount_percent > 0 AND full_term_discount_percent <= 100),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.registration_settings (id, enabled, min_full_term_classes, full_term_discount_percent)
VALUES (1, true, 2, 96.00)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.registration_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY registration_settings_admin_select
  ON public.registration_settings FOR SELECT TO authenticated
  USING (public.is_admin());

CREATE POLICY registration_settings_admin_update
  ON public.registration_settings FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT, UPDATE ON public.registration_settings TO authenticated;
REVOKE ALL ON public.registration_settings FROM anon;

CREATE OR REPLACE FUNCTION public.rpc_submit_full_term_registrations(
  p_class_ids uuid[],
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_id      uuid := auth.uid();
  v_key_status      text;
  v_key_user_id     uuid;
  v_key_snapshot    jsonb;
  v_class_id        uuid;
  v_class           record;
  v_existing_count  int;
  v_used_count      int;
  v_failures        jsonb := '[]'::jsonb;
  v_venue_order_ids jsonb := '{}'::jsonb;
  v_order_ids_arr   uuid[] := ARRAY[]::uuid[];
  v_created_ids     uuid[] := ARRAY[]::uuid[];
  v_order_id        uuid;
  v_new_reg_id      uuid;
  v_result          jsonb;
  v_now             timestamptz := now();
  v_venue_key       text;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION '必須登入才能報名' USING ERRCODE = '28000';
  END IF;

  IF p_class_ids IS NULL OR array_length(p_class_ids, 1) IS NULL THEN
    RAISE EXCEPTION '請至少選擇一堂課' USING ERRCODE = '22023';
  END IF;

  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) = 0 THEN
    RAISE EXCEPTION '缺少 idempotency key' USING ERRCODE = '22023';
  END IF;

  -- ---- 1. Idempotency：查詢或建立 key 列（正確處理併發競態） ----
  LOOP
    SELECT status, user_id, response_snapshot
      INTO v_key_status, v_key_user_id, v_key_snapshot
    FROM public.idempotency_keys
    WHERE key = p_idempotency_key
    FOR UPDATE;

    IF FOUND THEN
      IF v_key_user_id <> v_student_id THEN
        RAISE EXCEPTION 'idempotency key 不屬於目前使用者' USING ERRCODE = '42501';
      END IF;

      IF v_key_status = 'completed' THEN
        RETURN v_key_snapshot;
      ELSIF v_key_status = 'processing' THEN
        RAISE EXCEPTION '上一次相同的送出仍在處理中，請稍後再試' USING ERRCODE = '55P03';
      ELSE
        -- 'failed'（例如上一次系統性錯誤）：允許重新嘗試
        UPDATE public.idempotency_keys SET status = 'processing' WHERE key = p_idempotency_key;
        EXIT;
      END IF;
    ELSE
      BEGIN
        INSERT INTO public.idempotency_keys (key, user_id, action_type, status, expires_at)
        VALUES (p_idempotency_key, v_student_id, 'submit_full_term_registrations', 'processing', v_now + interval '24 hours');
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        -- 另一個併發請求搶先用同一把全新 key 建立了這筆列，回到迴圈開頭
        -- 重新 SELECT ... FOR UPDATE（這次一定找得到，並會被鎖住直到對方完成）。
        CONTINUE;
      END;
    END IF;
  END LOOP;

  -- ---- 2. 核心邏輯（包在子區塊內，任何未預期錯誤都會把 key 標記為 failed 再往外拋） ----
  BEGIN
    -- 驗證階段：依 class_id 排序鎖定，固定順序避免 deadlock
    FOR v_class_id IN
      SELECT DISTINCT c_id FROM unnest(p_class_ids) AS c_id ORDER BY c_id
    LOOP
      SELECT c.id, c.venue_id, c.term_id, c.capacity, c.full_term_price,
             c.is_active, c.is_open_for_registration, c.name
        INTO v_class
      FROM public.classes c
      WHERE c.id = v_class_id
      FOR UPDATE;

      IF NOT FOUND THEN
        v_failures := v_failures || jsonb_build_object('class_id', v_class_id, 'reason', 'not_found');
        CONTINUE;
      END IF;

      IF NOT v_class.is_active OR NOT v_class.is_open_for_registration THEN
        v_failures := v_failures || jsonb_build_object(
          'class_id', v_class_id, 'class_name', v_class.name, 'reason', 'not_open');
        CONTINUE;
      END IF;

      SELECT COUNT(*) INTO v_existing_count
      FROM public.registrations r
      WHERE r.student_id = v_student_id AND r.class_id = v_class_id
        AND r.registration_type = 'full_term' AND r.status = 'active';

      IF v_existing_count > 0 THEN
        v_failures := v_failures || jsonb_build_object(
          'class_id', v_class_id, 'class_name', v_class.name, 'reason', 'already_registered');
        CONTINUE;
      END IF;

      SELECT COUNT(*) INTO v_used_count
      FROM public.registrations r
      WHERE r.class_id = v_class_id
        AND r.registration_type = 'full_term' AND r.status = 'active';

      IF v_used_count >= v_class.capacity THEN
        v_failures := v_failures || jsonb_build_object(
          'class_id', v_class_id, 'class_name', v_class.name, 'reason', 'full');
        CONTINUE;
      END IF;
    END LOOP;

    IF jsonb_array_length(v_failures) > 0 THEN
      -- All-or-nothing：有任何一堂失敗就整批不建立，直接回傳失敗清單。
      v_result := jsonb_build_object(
        'success', false,
        'failures', v_failures,
        'order_ids', '[]'::jsonb,
        'registration_ids', '[]'::jsonb
      );

      UPDATE public.idempotency_keys
      SET status = 'completed', response_snapshot = v_result
      WHERE key = p_idempotency_key;

      RETURN v_result;
    END IF;

    -- 全部通過驗證：依 venue_id 分組建立 orders，寫入 registrations 與 audit_logs
    FOR v_class_id IN
      SELECT DISTINCT c_id FROM unnest(p_class_ids) AS c_id ORDER BY c_id
    LOOP
      SELECT c.id, c.venue_id, c.term_id, c.full_term_price, c.name
        INTO v_class
      FROM public.classes c
      WHERE c.id = v_class_id;

      v_venue_key := v_class.venue_id::text;

      IF v_venue_order_ids ? v_venue_key THEN
        v_order_id := (v_venue_order_ids ->> v_venue_key)::uuid;
      ELSE
        INSERT INTO public.orders (student_id, venue_id, status, subtotal_amount, total_amount)
        VALUES (v_student_id, v_class.venue_id, 'confirmed', 0, 0)
        RETURNING id INTO v_order_id;

        v_venue_order_ids := v_venue_order_ids || jsonb_build_object(v_venue_key, v_order_id::text);
        v_order_ids_arr := v_order_ids_arr || v_order_id;
      END IF;

      INSERT INTO public.registrations (student_id, class_id, term_id, order_id, registration_type, status)
      VALUES (v_student_id, v_class_id, v_class.term_id, v_order_id, 'full_term', 'active')
      RETURNING id INTO v_new_reg_id;

      v_created_ids := v_created_ids || v_new_reg_id;

      INSERT INTO public.audit_logs (actor_id, actor_role, action, entity_type, entity_id, after_data)
      VALUES (
        v_student_id, 'student', 'registration_create', 'registrations', v_new_reg_id,
        jsonb_build_object(
          'class_id', v_class_id, 'class_name', v_class.name,
          'order_id', v_order_id, 'registration_type', 'full_term', 'status', 'active'
        )
      );
    END LOOP;

    -- 依實際建立的 orders 回填價格快照（伺服器端計算，不信任前端金額）。
    -- 同一次提交中，同一期別達到設定的最低堂數時，該期別所有期課套用多堂優惠。
    UPDATE public.orders o
    SET subtotal_amount = t.subtotal, total_amount = t.total
    FROM (
      WITH selected_term_counts AS (
        SELECT c.term_id, COUNT(DISTINCT c.id)::int AS class_count
        FROM public.classes c
        WHERE c.id = ANY (p_class_ids)
        GROUP BY c.term_id
      ), settings AS (
        SELECT enabled, min_full_term_classes, full_term_discount_percent
        FROM public.registration_settings
        WHERE id = 1
      )
      SELECT
        r.order_id,
        COALESCE(SUM(c.full_term_price), 0) AS subtotal,
        ROUND(COALESCE(SUM(
          c.full_term_price * CASE
            WHEN s.enabled AND tc.class_count >= s.min_full_term_classes
              THEN s.full_term_discount_percent / 100.0
            ELSE 1
          END
        ), 0), 0) AS total
      FROM public.registrations r
      JOIN public.classes c ON c.id = r.class_id
      JOIN selected_term_counts tc ON tc.term_id = c.term_id
      CROSS JOIN settings s
      WHERE r.order_id = ANY (v_order_ids_arr)
      GROUP BY r.order_id
    ) t
    WHERE o.id = t.order_id;

    SELECT jsonb_agg(jsonb_build_object('class_id', c.id, 'class_name', c.name, 'registration_id', r.id))
      INTO v_result
    FROM public.registrations r
    JOIN public.classes c ON c.id = r.class_id
    WHERE r.id = ANY (v_created_ids);

    v_result := jsonb_build_object(
      'success', true,
      'failures', '[]'::jsonb,
      'order_ids', to_jsonb(v_order_ids_arr),
      'registration_ids', to_jsonb(v_created_ids),
      'classes', COALESCE(v_result, '[]'::jsonb)
    );

    UPDATE public.idempotency_keys
    SET status = 'completed', response_snapshot = v_result
    WHERE key = p_idempotency_key;

    RETURN v_result;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.idempotency_keys SET status = 'failed' WHERE key = p_idempotency_key;
    RAISE;
  END;
END;
$$;

COMMENT ON FUNCTION public.rpc_submit_full_term_registrations(uuid[], text) IS
  '原子性的多堂期課報名 RPC，全部成功或全部失敗。回傳 jsonb：{success, failures[], order_ids[], registration_ids[], classes[]}。failures[] 內每項為 {class_id, class_name?, reason}，reason 可能是 not_found/not_open/already_registered/full。前端依 success 顯示確認頁或逐項失敗原因，失敗時未建立任何資料，可直接調整選擇後重新送出。';
