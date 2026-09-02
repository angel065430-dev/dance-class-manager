-- Registration MVP — P0
-- 20260902100007_orders_and_registrations.sql
--
-- 對應 REGISTRATION_MVP_PLAN.md 第 B 節「報名 MVP 的完整資料模型」
-- （已於 Phase 3/4 Plan 對話中經使用者確認）。
--
-- 範圍說明：
--   - 只支援「期課（整期）報名」；`registration_type`/`class_session_id`
--     從一開始就預留單堂報名的擴充能力（方案 A），但 MVP 階段
--     class_session_id 恆為 NULL，沒有任何 RPC 會寫入 single_session。
--   - 不建立 `order_items`：MVP 只有「期課」一種商品型態，`registrations`
--     本身已經是明細，沒有必要再疊一層。等 Phase 之後要做單堂／特別活動時
--     再評估是否需要，不影響本次已完成的部分。
--   - 不建立付款欄位／流程：`orders.subtotal_amount`/`total_amount` 只是
--     伺服器端計算的價格快照（避免完全沒有金額記錄），不代表已收款，
--     真正的付款狀態流程留待 P1。
--   - `idempotency_key` 不重複建欄位：直接沿用 Phase 2 已建立的
--     `idempotency_keys` 表（`response_snapshot jsonb` 存放完整回傳結果），
--     由呼叫端傳入同一把 key 即可重放先前結果，不需要在 orders 上
--     再存一份（多場地拆單時，一次提交會產生多筆 orders，若硬要求
--     `orders.idempotency_key` 唯一，反而需要额外衍生 key 的邏輯，
--     增加不必要的複雜度）。

-- ---------------------------------------------------------------------------
-- orders
-- ---------------------------------------------------------------------------
CREATE TABLE public.orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id      uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  venue_id        uuid NOT NULL REFERENCES public.venues (id) ON DELETE RESTRICT,
  status          text NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled')),
  subtotal_amount numeric(10, 2) NOT NULL CHECK (subtotal_amount >= 0),
  total_amount    numeric(10, 2) NOT NULL CHECK (total_amount >= 0),
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.orders IS
  '報名批次容器（MVP 瘦身版）。一次提交多堂期課報名時，依 venue_id 分組各建立一筆（對應 PHASE_0_AUDIT_REPORT.md 第 11.3 節已確認的多場地拆單規則）。不含付款流程，status 目前只用 confirmed/cancelled。ON DELETE RESTRICT：交易性資料不因關聯資料被刪而遺失（呼應 AI_INSTRUCTIONS.md 第 24 節）。';

CREATE INDEX idx_orders_student_id ON public.orders (student_id);
CREATE INDEX idx_orders_venue_id ON public.orders (venue_id);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_select_own_or_admin
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (student_id = auth.uid() OR public.is_admin());

-- 刻意不開放 INSERT/UPDATE/DELETE 政策：所有寫入一律透過
-- rpc_submit_full_term_registrations()（SECURITY DEFINER）完成，
-- 與 audit_logs/idempotency_keys 已建立的模式一致。

-- ---------------------------------------------------------------------------
-- registrations
-- ---------------------------------------------------------------------------
CREATE TABLE public.registrations (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id         uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  class_id           uuid NOT NULL REFERENCES public.classes (id) ON DELETE RESTRICT,
  term_id            uuid NOT NULL REFERENCES public.terms (id) ON DELETE RESTRICT,
  order_id           uuid NOT NULL REFERENCES public.orders (id) ON DELETE RESTRICT,
  class_session_id   uuid REFERENCES public.class_sessions (id) ON DELETE RESTRICT,
  registration_type  text NOT NULL DEFAULT 'full_term' CHECK (registration_type IN ('full_term', 'single_session')),
  status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled')),
  created_at         timestamptz NOT NULL DEFAULT now(),
  cancelled_at       timestamptz,
  cancelled_reason   text,
  CONSTRAINT registrations_type_session_consistency CHECK (
    (registration_type = 'full_term' AND class_session_id IS NULL)
    OR
    (registration_type = 'single_session' AND class_session_id IS NOT NULL)
  )
);

COMMENT ON TABLE public.registrations IS
  '報名紀錄。MVP 階段只會產生 registration_type=''full_term''、class_session_id=NULL 的列。class_session_id/single_session 從一開始就保留給未來單堂報名擴充（REGISTRATION_MVP_PLAN.md 方案 A），現階段沒有任何 RPC 會寫入 single_session。';

-- 防重複報名：同一位學生對同一個班級/期別，最多只能有一筆有效的整期報名。
-- 這是最終防線（即使繞過 RPC 也擋得住）；rpc_submit_full_term_registrations
-- 內部也會先做一次友善檢查，避免學生直接看到裸的資料庫錯誤訊息。
CREATE UNIQUE INDEX ux_registrations_full_term_active
  ON public.registrations (student_id, class_id, term_id)
  WHERE registration_type = 'full_term' AND status = 'active';

CREATE INDEX idx_registrations_student_id ON public.registrations (student_id);
CREATE INDEX idx_registrations_class_id ON public.registrations (class_id);
CREATE INDEX idx_registrations_order_id ON public.registrations (order_id);
CREATE INDEX idx_registrations_status ON public.registrations (status);

-- ---------------------------------------------------------------------------
-- 資料完整性保護：registrations.term_id 必須與 class 實際所屬的 term 一致。
-- 與 Phase 2 的 trg_classes_check_term_venue 屬於同一類技術性保護
-- （超出字面欄位/約束清單，但呼應 AI_INSTRUCTIONS.md 第 7、9 節對資料
-- 完整性的一般性要求），避免未來任何 RPC 寫入時填錯 term_id。
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_registrations_check_class_term()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actual_term_id uuid;
BEGIN
  SELECT term_id INTO v_actual_term_id
  FROM public.classes
  WHERE id = NEW.class_id;

  IF v_actual_term_id IS DISTINCT FROM NEW.term_id THEN
    RAISE EXCEPTION 'registrations.term_id (%) 與 class_id (%) 實際所屬的 term_id (%) 不一致',
      NEW.term_id, NEW.class_id, v_actual_term_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_registrations_check_class_term
  BEFORE INSERT OR UPDATE OF class_id, term_id ON public.registrations
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_registrations_check_class_term();

ALTER TABLE public.registrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY registrations_select_own_or_admin
  ON public.registrations
  FOR SELECT
  TO authenticated
  USING (student_id = auth.uid() OR public.is_admin());

-- 同樣刻意不開放 INSERT/UPDATE/DELETE 政策，寫入僅透過
-- rpc_submit_full_term_registrations()。
