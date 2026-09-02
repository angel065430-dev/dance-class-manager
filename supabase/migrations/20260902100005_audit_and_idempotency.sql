-- Phase 2 — Database Foundation
-- 20260902100005_audit_and_idempotency.sql
--
-- 對應 PHASE_0_AUDIT_REPORT.md 第 5.2 節 `audit_logs` / `idempotency_keys`，
-- 依第 8.1 節確認的排序調整提前到 Phase 2 建立（原因：Phase 5 起的多個
-- RPC 一開始就需要寫入稽核紀錄與檢查 idempotency key）。
--
-- 明確不在本檔案範圍內：任何實際會呼叫這兩張表的 RPC（例如
-- rpc_create_registration、rpc_reserve_makeup 等）都屬於後續功能 Phase
-- 的工作，本檔案只建立表結構與 RLS，不建立任何業務 RPC。

-- ---------------------------------------------------------------------------
-- audit_logs
-- ---------------------------------------------------------------------------
CREATE TABLE public.audit_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    uuid REFERENCES public.profiles (id) ON DELETE SET NULL,
  actor_role  text,
  action      text NOT NULL,
  entity_type text NOT NULL,
  entity_id   uuid,
  before_data jsonb,
  after_data  jsonb,
  reason      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.audit_logs IS
  '稽核紀錄，對應 MASTER_SPEC.md 第 37 節與 AI_INSTRUCTIONS.md 第 22 節列出的必稽核操作清單。actor_id 為 null 代表系統自動動作（例如排程將逾期補課預約標記為 expired）。此表為唯獨（append-only）設計：不開放任何角色的 UPDATE／DELETE。';

CREATE INDEX idx_audit_logs_entity ON public.audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_logs_actor_id ON public.audit_logs (actor_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs (created_at);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 對應第 4.3.5 節：「僅管理員可 SELECT；INSERT 僅由資料庫函式/觸發器執行，
-- 不對任何角色開放直接 INSERT」。因此這裡刻意只建立 SELECT 政策，
-- 完全不建立 INSERT/UPDATE/DELETE 政策——對 anon/authenticated 而言，
-- 沒有政策等於預設拒絕。未來 Phase 5 起的 SECURITY DEFINER RPC
-- 會以函式擁有者（資料表擁有者）身份執行寫入，天然略過 RLS，
-- 不需要、也不應該為 anon/authenticated 開放 INSERT policy。
CREATE POLICY audit_logs_select_admin_only
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- idempotency_keys
-- ---------------------------------------------------------------------------
CREATE TABLE public.idempotency_keys (
  key               text PRIMARY KEY,
  user_id           uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  action_type       text NOT NULL,
  request_hash      text,
  response_snapshot jsonb,
  status            text NOT NULL DEFAULT 'processing' CHECK (status IN ('processing', 'completed', 'failed')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  expires_at        timestamptz NOT NULL
);

COMMENT ON TABLE public.idempotency_keys IS
  '冪等鍵，防止重複送出造成重複訂單/報名/補課預約/優惠碼扣用，對應 MASTER_SPEC.md 第 38 節。key 由客戶端產生的 UUID 字串。';

CREATE INDEX idx_idempotency_keys_user_id ON public.idempotency_keys (user_id);
CREATE INDEX idx_idempotency_keys_expires_at ON public.idempotency_keys (expires_at);

ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY idempotency_keys_select_own_or_admin
  ON public.idempotency_keys
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 對應第 4.3.5 節：「使用者僅能 INSERT/SELECT 自己建立的 key，不可
-- UPDATE」。status 由後續 Phase 的 RPC 以 SECURITY DEFINER 身份內部管理，
-- 因此這裡不開放 UPDATE 政策給 anon/authenticated。
CREATE POLICY idempotency_keys_insert_own
  ON public.idempotency_keys
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());
