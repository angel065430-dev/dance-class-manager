CREATE TABLE IF NOT EXISTS public.venue_payment_settings (
  venue_id uuid PRIMARY KEY REFERENCES public.venues(id) ON DELETE CASCADE,
  bank_name text,
  bank_code text,
  bank_account text,
  line_pay_instructions text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.venue_payment_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_can_read_payment_settings"
ON public.venue_payment_settings
FOR SELECT
TO authenticated
USING (is_active = true OR public.is_admin());

CREATE POLICY "admin_can_insert_payment_settings"
ON public.venue_payment_settings
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "admin_can_update_payment_settings"
ON public.venue_payment_settings
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "admin_can_delete_payment_settings"
ON public.venue_payment_settings
FOR DELETE
TO authenticated
USING (public.is_admin());
