CREATE OR REPLACE FUNCTION public.trg_profiles_protect_phone()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone
     AND auth.role() IS DISTINCT FROM 'service_role'
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'phone 欄位不可由使用者直接修改，請透過帳號設定流程變更登入手機號碼'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_profiles_protect_phone() IS
  '禁止一般使用者直接修改登入手機；只允許 admin 或受信任 Edge Function 的 service_role 完成帳號 provisioning／校正。';