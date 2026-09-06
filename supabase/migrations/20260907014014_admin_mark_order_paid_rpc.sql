CREATE OR REPLACE FUNCTION public.rpc_admin_mark_order_paid(
  p_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.orders
  SET
    payment_status = 'paid',
    paid_at = now()
  WHERE id = p_order_id
    AND payment_status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found_or_already_paid';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_mark_order_paid(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_mark_order_paid(uuid) TO authenticated;
