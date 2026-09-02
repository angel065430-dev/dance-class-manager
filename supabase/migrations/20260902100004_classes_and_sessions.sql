-- Phase 2 — Database Foundation
-- 20260902100004_classes_and_sessions.sql
--
-- 對應 PHASE_0_AUDIT_REPORT.md 第 5.2 節 `classes` / `class_sessions`。
--
-- 明確不在本檔案範圍內（刻意不做，避免搶先做到後面 Phase 的工作）：
--   - fn_session_used_seats(session_id)（第 5.3 節）：這個函式需要讀取
--     registrations（Phase 5）與 makeup_reservations（Phase 9），這兩張
--     表在 Phase 2 都還不存在。若現在就建立一個「假的」或「部分邏輯」的
--     版本，之後 Phase 5/9 若忘記同步更新，會產生「函式存在但邏輯不完整」
--     的風險，比「函式還不存在」更危險，因此完全不建立，留到 Phase 5
--     報名功能實際開發時再建立完整版本。
--   - class_sessions 的產生邏輯（依 weekdays/日期區間展開成實際課堂列）：
--     屬於 Phase 4（Admin Foundation）管理介面的功能，不是 Schema 本身。

-- ---------------------------------------------------------------------------
-- classes
-- ---------------------------------------------------------------------------
CREATE TABLE public.classes (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id                    uuid NOT NULL REFERENCES public.venues (id) ON DELETE RESTRICT,
  term_id                     uuid NOT NULL REFERENCES public.terms (id) ON DELETE RESTRICT,
  name                        text NOT NULL,
  weekdays                    integer[] NOT NULL,
  start_time                  time NOT NULL,
  end_time                    time NOT NULL,
  capacity                    integer NOT NULL CHECK (capacity >= 0),
  business_mode               text NOT NULL CHECK (business_mode IN ('self_operated', 'external_center')),
  full_term_price             numeric(10, 2) CHECK (full_term_price IS NULL OR full_term_price >= 0),
  single_session_price        numeric(10, 2) CHECK (single_session_price IS NULL OR single_session_price >= 0),
  default_base_makeup_capacity integer NOT NULL DEFAULT 0 CHECK (default_base_makeup_capacity >= 0),
  is_open_for_registration    boolean NOT NULL DEFAULT false,
  is_active                   boolean NOT NULL DEFAULT true,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT classes_end_after_start CHECK (end_time > start_time),
  CONSTRAINT classes_weekdays_valid CHECK (
    array_length(weekdays, 1) > 0
    AND weekdays <@ ARRAY[0, 1, 2, 3, 4, 5, 6]
  )
);

COMMENT ON TABLE public.classes IS
  '班級主檔。business_mode 冗餘存放自 venues，簡化查詢（見第 5.2 節設計說明）。weekdays 以 0-6 表示星期日到星期六。';
COMMENT ON COLUMN public.classes.is_open_for_registration IS
  '是否開放報名，僅影響「能否報名」；瀏覽可見性由 is_active 與所屬場地的公開性決定，兩者是不同的概念（見本次完成報告的欄位語意說明）。';

CREATE INDEX idx_classes_venue_term ON public.classes (venue_id, term_id);
CREATE INDEX idx_classes_open_for_registration ON public.classes (is_open_for_registration);

CREATE TRIGGER trg_classes_set_updated_at
  BEFORE UPDATE ON public.classes
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 資料完整性保護：classes.venue_id 必須與 classes.term_id 所屬的
-- terms.venue_id 一致，避免「班級掛在 A 場地、卻選了 B 場地的期別」這種
-- 純粹的資料錯誤。這是資料庫層級的技術性保護（不是新的業務規則），
-- CHECK 約束無法跨表查詢，因此以 trigger 實作。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_classes_check_term_venue()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_term_venue_id uuid;
BEGIN
  SELECT venue_id INTO v_term_venue_id FROM public.terms WHERE id = NEW.term_id;

  IF v_term_venue_id IS NULL THEN
    RAISE EXCEPTION 'term_id % 不存在', NEW.term_id
      USING ERRCODE = '23503';
  END IF;

  IF v_term_venue_id IS DISTINCT FROM NEW.venue_id THEN
    RAISE EXCEPTION '班級的 venue_id (%) 必須與所屬期別的 venue_id (%) 一致', NEW.venue_id, v_term_venue_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_classes_check_term_venue
  BEFORE INSERT OR UPDATE OF venue_id, term_id ON public.classes
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_classes_check_term_venue();

-- ---------------------------------------------------------------------------
-- fn_is_class_public(p_class_id)
--
-- 沿用 fn_is_venue_public() 的公開性判斷，再疊加 classes 自己的 is_active，
-- 集中定義「這個班級是否對一般訪客可見」，供 classes 本身與 class_sessions
-- 的公開瀏覽政策共用。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_is_class_public(p_class_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.classes c
    WHERE c.id = p_class_id
      AND c.is_active = true
      AND public.fn_is_venue_public(c.venue_id)
  );
$$;

COMMENT ON FUNCTION public.fn_is_class_public(uuid) IS
  '判斷指定班級是否 is_active 且所屬場地公開，供 classes 與 class_sessions 的公開瀏覽 RLS 政策共用。';

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

CREATE POLICY classes_select_public_or_admin
  ON public.classes
  FOR SELECT
  TO anon, authenticated
  USING (
    (is_active = true AND public.fn_is_venue_public(venue_id))
    OR public.is_admin()
  );

CREATE POLICY classes_insert_admin_only
  ON public.classes
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY classes_update_admin_only
  ON public.classes
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY classes_delete_admin_only
  ON public.classes
  FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- class_sessions
-- ---------------------------------------------------------------------------
CREATE TABLE public.class_sessions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id             uuid NOT NULL REFERENCES public.classes (id) ON DELETE RESTRICT,
  session_date         date NOT NULL,
  start_at             timestamptz NOT NULL,
  end_at               timestamptz NOT NULL,
  status               text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled')),
  base_makeup_capacity integer NOT NULL DEFAULT 0 CHECK (base_makeup_capacity >= 0),
  notes                text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT class_sessions_class_date_unique UNIQUE (class_id, session_date),
  CONSTRAINT class_sessions_end_after_start CHECK (end_at > start_at)
);

COMMENT ON TABLE public.class_sessions IS
  '單堂課堂實例。base_makeup_capacity 預設應等於 classes.default_base_makeup_capacity，可逐堂覆蓋（第 5.2 節），實際「建立課堂時帶入預設值」的邏輯屬於 Phase 4 管理介面工作，本 migration 只建立欄位本身，DEFAULT 0 只是資料庫層級的保底值。';

CREATE INDEX idx_class_sessions_class_id ON public.class_sessions (class_id);
CREATE INDEX idx_class_sessions_session_date ON public.class_sessions (session_date);
CREATE INDEX idx_class_sessions_start_at ON public.class_sessions (start_at);

CREATE TRIGGER trg_class_sessions_set_updated_at
  BEFORE UPDATE ON public.class_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.class_sessions ENABLE ROW LEVEL SECURITY;

-- 公開瀏覽不因 status='cancelled' 而隱藏（停課的課堂前台仍應顯示，
-- 通常會以劃線／註記方式呈現，而不是讓使用者以為它從未存在），
-- 可見性完全由所屬班級／場地的公開性決定。
CREATE POLICY class_sessions_select_public_or_admin
  ON public.class_sessions
  FOR SELECT
  TO anon, authenticated
  USING (public.fn_is_class_public(class_id) OR public.is_admin());

CREATE POLICY class_sessions_insert_admin_only
  ON public.class_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY class_sessions_update_admin_only
  ON public.class_sessions
  FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY class_sessions_delete_admin_only
  ON public.class_sessions
  FOR DELETE
  TO authenticated
  USING (public.is_admin());
