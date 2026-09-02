-- Phase 2 — Database Foundation
-- 20260902100003_venues_terms.sql
--
-- 對應 PHASE_0_AUDIT_REPORT.md 第 5.2 節 `venues` / `terms`，
-- 以及第 6 節 RLS Strategy 摘要「公開瀏覽資料：SELECT 對所有人開放但僅限
-- is_active = true AND is_public = true」。

-- ---------------------------------------------------------------------------
-- venues
-- ---------------------------------------------------------------------------
CREATE TABLE public.venues (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  address       text,
  business_mode text NOT NULL CHECK (business_mode IN ('self_operated', 'external_center')),
  is_active     boolean NOT NULL DEFAULT true,
  is_public     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.venues IS
  '場地主檔。business_mode 區分自營教室（self_operated）與運動中心／外部場地（external_center），見 MASTER_SPEC.md 第 5.2 節。';

CREATE INDEX idx_venues_business_mode ON public.venues (business_mode);
CREATE INDEX idx_venues_is_active ON public.venues (is_active);

CREATE TRIGGER trg_venues_set_updated_at
  BEFORE UPDATE ON public.venues
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- fn_is_venue_public(p_venue_id)
--
-- 集中判斷「這個場地目前是否應該對一般訪客／未登入使用者可見」的邏輯，
-- 供 venues 本身與後續 terms/classes/class_sessions 的公開瀏覽政策共用，
-- 避免同一條件在多張表的 RLS 政策中各自重複撰寫（呼應 AI_INSTRUCTIONS.md
-- 第 31 節「Critical business rules should be centralized」）。
-- SECURITY DEFINER 讓下游資料表（terms/classes/class_sessions）的政策
-- 可以透過這個函式間接讀取 venues，而不需要對 venues 額外開放存取權限。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_is_venue_public(p_venue_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.venues v
    WHERE v.id = p_venue_id
      AND v.is_active = true
      AND v.is_public = true
  );
$$;

COMMENT ON FUNCTION public.fn_is_venue_public(uuid) IS
  '判斷指定場地是否 is_active AND is_public，供 terms/classes/class_sessions 的公開瀏覽 RLS 政策共用同一套「可見性」定義。';

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

CREATE POLICY venues_select_public_or_admin
  ON public.venues
  FOR SELECT
  TO anon, authenticated
  USING ((is_active = true AND is_public = true) OR public.is_admin());

CREATE POLICY venues_insert_admin_only
  ON public.venues
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY venues_update_admin_only
  ON public.venues
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY venues_delete_admin_only
  ON public.venues
  FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- terms
-- ---------------------------------------------------------------------------
CREATE TABLE public.terms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE RESTRICT,
  name            text NOT NULL,
  start_date      date NOT NULL,
  end_date        date NOT NULL,
  leave_rule_note text,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT terms_date_range_valid CHECK (end_date >= start_date)
);

COMMENT ON TABLE public.terms IS
  '期別主檔，隸屬單一場地。見 MASTER_SPEC.md 第 6 節。';

CREATE INDEX idx_terms_venue_id ON public.terms (venue_id);
CREATE INDEX idx_terms_date_range ON public.terms (start_date, end_date);

CREATE TRIGGER trg_terms_set_updated_at
  BEFORE UPDATE ON public.terms
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.terms ENABLE ROW LEVEL SECURITY;

-- 公開瀏覽判斷式：本身 is_active，且所屬場地符合 fn_is_venue_public()。
-- terms 資料表本身沒有獨立的 is_public 欄位（PHASE_0_AUDIT_REPORT.md
-- 第 5.2 節的欄位清單中沒有列出），第 6 節 RLS Strategy 摘要提到的
-- 「is_active = true AND is_public = true」在此解讀為：is_public 這個
-- 判斷條件由所屬場地決定（可見性沿場地往下繼承），is_active 則是 terms
-- 自己的欄位。這是本輪 Schema 與 RLS 摘要兩節措辭不完全一致時，選擇的
-- 「影響最小、不擴大公開範圍」的解讀方式，明確記錄於本次完成報告，
-- 供你確認是否符合預期（呼應 AI_INSTRUCTIONS.md 第 33 節：需求模糊時
-- 記錄選擇並標記待確認，而不是悄悄自行決定）。
CREATE POLICY terms_select_public_or_admin
  ON public.terms
  FOR SELECT
  TO anon, authenticated
  USING (
    (is_active = true AND public.fn_is_venue_public(venue_id))
    OR public.is_admin()
  );

CREATE POLICY terms_insert_admin_only
  ON public.terms
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY terms_update_admin_only
  ON public.terms
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY terms_delete_admin_only
  ON public.terms
  FOR DELETE
  TO authenticated
  USING (public.is_admin());
