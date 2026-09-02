-- Registration MVP — P0
-- 20260902100006_auth_provisioning.sql
--
-- 對應 REGISTRATION_MVP_PLAN.md 附錄「待你確認的事項」第 1 點（已確認）：
--   1. profiles.phone 改為 nullable，解決「管理員以 Email+Password 註冊時
--      auth.users.phone 為 NULL」與「profiles.phone 原本 UNIQUE NOT NULL」的衝突。
--      Postgres 的 UNIQUE 約束本來就允許多個 NULL 並存，因此改為 nullable
--      不影響學生手機號碼本身的唯一性保護。
--   2. 建立 auth.users 新增時自動建立 profiles/user_roles 的 Trigger
--      （對應 PHASE_0_AUDIT_REPORT.md 第 4.3.4 節、第 4.3.1 節第 1 點）。
--
-- 角色指派邏輯（本檔案的核心設計決策，已於 Phase 3/4 Plan 對話中向使用者說明）：
--   - NEW.phone IS NOT NULL（學生透過 Phone+Password 自助註冊）
--       → 自動指派 user_roles(role='student')。
--   - NEW.phone IS NULL（管理員透過 Email+Password，一般由既有管理員或
--     Service Role 建立）
--       → 只建立 profiles 列（phone=NULL），不自動指派任何角色。
--     admin 角色維持 Phase 2 migration 已記錄的規則：只能由既有管理員
--     手動指派（user_roles 的 INSERT 政策要求 is_admin()），不因為用
--     Email 註冊就自動視為 admin，避免自助升級風險。

-- ---------------------------------------------------------------------------
-- profiles.phone 改為 nullable
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ALTER COLUMN phone DROP NOT NULL;

COMMENT ON COLUMN public.profiles.phone IS
  '正規化為 E.164 格式的手機號碼（學生登入識別碼）。管理員帳號（Email+Password 登入）此欄位為 NULL。UNIQUE 約束允許多個 NULL 並存，不影響學生手機唯一性保護。';

-- ---------------------------------------------------------------------------
-- handle_new_auth_user()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone)
  VALUES (NEW.id, NEW.phone)
  ON CONFLICT (id) DO NOTHING;

  IF NEW.phone IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'student')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_auth_user() IS
  'auth.users 新增列時自動建立對應的 profiles 列；若該筆帳號有手機號碼（學生自助註冊），一併指派 student 角色。SECURITY DEFINER 以便寫入受 RLS 保護的 profiles/user_roles。ON CONFLICT DO NOTHING 讓此函式對重複觸發保持冪等。';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

COMMENT ON TRIGGER on_auth_user_created ON auth.users IS
  '對應 PHASE_0_AUDIT_REPORT.md 第 4.3.4 節：新使用者註冊時自動建立 profiles 列並（視情況）指派 student 角色，前端不需要、也不應該自行寫入這兩張表。';
