-- Phase 2 — Database Foundation
-- 20260902100002_profiles_and_roles.sql
--
-- 對應 PHASE_0_AUDIT_REPORT.md 第 5.2 節 `profiles` / `user_roles`。
-- 本檔只建立 Phase 2「Database Foundation」範圍內的欄位與 RLS 基礎；
-- Phase 3（Authentication & Authorization）才會新增：
--   - auth.users 新增時自動建立 profiles/user_roles 的 Trigger（4.3.4 節）
--   - failed_login_count / locked_until 登入鎖定欄位（4.3.1 節第 6 點）
-- 這裡刻意不提前建立，理由見本次交付的完成報告「Not Implemented」章節。
--
-- 檔案內順序說明：CREATE POLICY 與 LANGUAGE sql 函式一樣，PostgreSQL 會在
-- 建立當下就對其中引用的函式／資料表做存在性檢查，因此本檔案刻意把兩張表
-- 都先建立好、is_admin() 也先定義好，最後才統一建立所有 RLS 政策，
-- 而不是每張表建立完就立刻掛政策（避免 profiles 的政策想引用還不存在的
-- is_admin()，或 is_admin() 想引用還不存在的 user_roles）。

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  phone       text NOT NULL,
  name        text,
  line_id     text,
  remit_last5 text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_phone_unique UNIQUE (phone)
);

COMMENT ON TABLE public.profiles IS
  '學生／管理員的公開身份資料，1:1 對應 auth.users。id = auth.users.id。';
COMMENT ON COLUMN public.profiles.phone IS
  '正規化為 E.164 格式的手機號碼（見 PHASE_0_AUDIT_REPORT.md 第 4.3.1 節第 2 點），需與 auth.users.phone 保持一致；同步機制留待 Phase 3 以 Trigger 實作。';

CREATE TRIGGER trg_profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- user_roles
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_roles (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('student', 'admin')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_roles_user_role_unique UNIQUE (user_id, role)
);

COMMENT ON TABLE public.user_roles IS
  '使用者角色指派（多對多），角色目前僅 student / admin 兩種。管理員角色只能由既有管理員透過受保護的後台操作指派，見 PHASE_0_AUDIT_REPORT.md 第 4.3.4 節。';

CREATE INDEX idx_user_roles_user_id ON public.user_roles (user_id);

-- ---------------------------------------------------------------------------
-- is_admin()
--
-- 對應 PHASE_0_AUDIT_REPORT.md 第 4.3.5 節：「建立 SECURITY DEFINER 輔助
-- 函式 is_admin()（查詢 user_roles，繞過 RLS 遞迴問題），所有牽涉『本人或
-- 管理員』的政策皆呼叫此函式。」必須放在 user_roles 表建立之後——這是
-- LANGUAGE sql 函式，PostgreSQL 在 CREATE FUNCTION 當下就會 parse-analyze
-- 函式本體，要求被參照的資料表已經存在；也必須放在下方所有 CREATE POLICY
-- 之前，理由相同（政策運算式在建立當下也會做同樣的存在性檢查）。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    WHERE ur.user_id = auth.uid()
      AND ur.role = 'admin'
  );
$$;

COMMENT ON FUNCTION public.is_admin() IS
  '回傳目前呼叫者（auth.uid()）是否具備 admin 角色。SECURITY DEFINER 以繞過 user_roles 自身的 RLS 遞迴問題，對應 PHASE_0_AUDIT_REPORT.md 第 4.3.5 節。';

-- ---------------------------------------------------------------------------
-- 防止使用者透過一般 UPDATE 權限自行竄改 phone（登入身份識別欄位）。
-- phone 的正確變更路徑是先透過 Supabase Auth 本身變更 auth.users.phone，
-- 再由（Phase 3 建立的）Trigger 同步回 profiles，而不是反向由使用者直接
-- 改 profiles.phone。管理員（is_admin()）例外，可直接於後台校正資料。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_profiles_protect_phone()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'phone 欄位不可由使用者直接修改，請透過帳號設定流程變更登入手機號碼'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_protect_phone
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_profiles_protect_phone();

-- ---------------------------------------------------------------------------
-- profiles RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_own_or_admin
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY profiles_update_own_or_admin
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- 刻意不開放 INSERT／DELETE 政策給 anon/authenticated：
--   - INSERT：Phase 3 才會建立「auth.users 新增時自動建立 profiles」的
--     Trigger，該 Trigger 以 SECURITY DEFINER／資料庫內部身份執行，
--     不需要、也不應該對前端開放直接 INSERT profiles。
--   - DELETE：使用者身份資料不做硬刪除（呼應 AI_INSTRUCTIONS.md 第 24 節
--     Soft Delete 原則），如需停用帳號，屬於 Phase 3 之後的管理員操作，
--     且應該是狀態轉換而非刪除列。

-- ---------------------------------------------------------------------------
-- user_roles RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_roles_select_own_or_admin
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 新增/修改/刪除角色僅限管理員（不開放自助升級，呼應 4.3.4 節）。
-- 注意：這是 Phase 2「RLS 基礎」層級的防護；正式的角色指派操作介面
-- 與更嚴謹的 RPC 包裝，留待實際需要角色管理 UI 的 Phase（Phase 3/4）實作。
CREATE POLICY user_roles_insert_admin_only
  ON public.user_roles
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY user_roles_update_admin_only
  ON public.user_roles
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY user_roles_delete_admin_only
  ON public.user_roles
  FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- 營運注意事項（非程式碼，寫在 migration 註解供未來維運人員閱讀）：
--
-- 因為 user_roles 的 INSERT 政策要求呼叫者 is_admin() 為真，而系統剛建立
-- 時不存在任何 admin，會產生「雞生蛋、蛋生雞」的啟動問題。第一個 admin
-- 帳號必須由具備 Service Role 權限的操作人員（例如透過 Supabase Dashboard
-- 的 SQL Editor，或使用 Service Role Key 的後端腳本）手動寫入
-- user_roles 一筆 role='admin' 的紀錄，之後才能透過應用程式內的管理員
-- 介面新增其他管理員。這是所有採用「資料庫角色表 + RLS 只允許管理員寫入」
-- 模式的系統都會遇到的標準啟動步驟，不是本次設計的缺陷。
-- ---------------------------------------------------------------------------
