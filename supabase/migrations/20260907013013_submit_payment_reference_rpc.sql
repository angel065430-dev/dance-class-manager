CREATE OR REPLACE FUNCTION public.rpc_submit_payment_reference(
  p_order_id uuid,
  p_payment_method text,
  p_payment_reference text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student_id uuid;
  v_payment_status text;
BEGIN
  SELECT student_id, payment_status
  INTO v_student_id, v_payment_status
  FROM public.orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_student_id <> auth.uid() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF v_payment_status <> 'pending' THEN
    RAISE EXCEPTION 'payment_already_confirmed';
  END IF;

  IF p_payment_method NOT IN ('bank_transfer', 'line_pay') THEN
    RAISE EXCEPTION 'invalid_payment_method';
  END IF;

  IF p_payment_method = 'bank_transfer' THEN
    IF p_payment_reference IS NULL
       OR p_payment_reference !~ '^[0-9]{5}$' THEN
      RAISE EXCEPTION 'invalid_payment_reference';
    END IF;
  END IF;

  UPDATE public.orders
  SET
    payment_method = p_payment_method,
    payment_reference =
      CASE
        WHEN p_payment_method = 'bank_transfer'
          THEN p_payment_reference
        ELSE NULL
      END
  WHERE id = p_order_id;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_submit_payment_reference(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_submit_payment_reference(uuid, text, text) TO authenticated;
