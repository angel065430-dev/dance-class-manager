ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_reference text;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_payment_reference_check;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_payment_reference_check
  CHECK (
    payment_reference IS NULL
    OR payment_reference ~ '^[0-9]{5}$'
  );
