-- REGISTRATION_MVP_PLAN.md — P0 功能與 RLS 測試
--
-- 沿用 Phase 2（phase2_rls_manual_check.sql）已驗證過的做法：自訂 PL/pgSQL
-- 斷言框架（非 pgTAP），fail-loud（任何一項失敗就 RAISE EXCEPTION），全程包在
-- BEGIN...ROLLBACK 內，不留下任何測試資料。
--
-- 涵蓋範圍：
--   1. auth.users 新增時的 Provisioning Trigger（手機註冊 → profiles+student；
--      Email 註冊 → 只有 profiles，phone=NULL，無自動角色）
--   2. orders/registrations 的 RLS（Student A 看不到 Student B）
--   3. fn_class_remaining_seats 基本正確性
--   4. rpc_submit_full_term_registrations：
--      - 單堂／多堂（含跨場地拆單）happy path
--      - 額滿 / 未開放報名 / 重複報名 / 不存在 的 all-or-nothing 失敗
--      - Idempotency：同一把 key 重送回傳相同結果、不重複建立資料
--   5. trg_registrations_check_class_term 資料完整性保護
--
-- 注意：多人同時搶最後一個名額的「真正併發」測試，因為需要多個獨立資料庫
-- 連線同時進行，無法在單一交易內完成，另外用獨立腳本
-- （concurrency_race_check，見對話中的驗證紀錄／Round 2 章節）驗證。

BEGIN;

CREATE TEMP TABLE _test_results (
  id serial PRIMARY KEY,
  description text,
  passed boolean
);
GRANT INSERT, SELECT ON _test_results TO anon, authenticated;
GRANT USAGE, SELECT ON _test_results_id_seq TO anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.assert(p_description text, p_condition boolean)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO _test_results (description, passed) VALUES (p_description, p_condition);
  IF p_condition THEN
    RAISE NOTICE 'PASS: %', p_description;
  ELSE
    RAISE WARNING 'FAIL: %', p_description;
  END IF;
END;
$$;

-- ===========================================================================
-- 0. Seed（以 postgres 超級使用者身份，繞過 RLS）
-- ===========================================================================

-- 0.1 學生透過「手機」註冊 → 應觸發 Trigger 自動建立 profiles + student 角色
INSERT INTO auth.users (id, phone) VALUES
  ('a0000000-0000-0000-0000-000000000001', '+886900000001'), -- Student A
  ('a0000000-0000-0000-0000-000000000002', '+886900000002'), -- Student B
  ('a0000000-0000-0000-0000-000000000003', '+886900000003'), -- Student C（用於跨場地/重複報名測試）
  ('a0000000-0000-0000-0000-000000000010', '+886900000010'), -- Student for capacity-full 情境
  ('a0000000-0000-0000-0000-000000000011', '+886900000011'); -- Student for capacity-full 情境（會失敗）

-- 0.2 管理員透過「Email」註冊 → 應只建立 profiles（phone=NULL），不應自動有任何角色
INSERT INTO auth.users (id, email) VALUES
  ('b0000000-0000-0000-0000-000000000099', 'admin@example.com');

-- Bootstrap 第一個管理員角色（沿用 Phase 2 已記錄的手動 Service Role 流程）
INSERT INTO user_roles (user_id, role) VALUES ('b0000000-0000-0000-0000-000000000099', 'admin');

-- 0.3 場地／期別／班級
INSERT INTO venues (id, name, address, business_mode, is_active, is_public) VALUES
  ('c0000000-0000-0000-0000-000000000001', '自營教室 A', '台北市...', 'self_operated', true, true),
  ('c0000000-0000-0000-0000-000000000002', '自營教室 B', '新北市...', 'self_operated', true, true);

INSERT INTO terms (id, venue_id, name, start_date, end_date, is_active) VALUES
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '2026 秋季班', '2026-09-01', '2026-12-01', true),
  ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', '2026 秋季班（教室B）', '2026-09-01', '2026-12-01', true);

INSERT INTO classes (id, venue_id, term_id, name, weekdays, start_time, end_time, capacity, business_mode, full_term_price, is_open_for_registration, is_active) VALUES
  ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', '爵士舞初階', ARRAY[1], '19:00', '20:00', 10, 'self_operated', 3000, true, true),
  ('e0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'KPOP 舞蹈', ARRAY[3], '19:00', '20:00', 10, 'self_operated', 3200, true, true),
  ('e0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', '未開放報名班', ARRAY[2], '19:00', '20:00', 10, 'self_operated', 2500, false, true),
  ('e0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', '只剩一位名額', ARRAY[4], '19:00', '20:00', 1, 'self_operated', 2800, true, true);

-- ===========================================================================
-- 1. Provisioning Trigger
-- ===========================================================================
SELECT pg_temp.assert(
  '手機註冊的學生自動建立 profiles 列',
  EXISTS (SELECT 1 FROM profiles WHERE id = 'a0000000-0000-0000-0000-000000000001' AND phone = '+886900000001')
);
SELECT pg_temp.assert(
  '手機註冊的學生自動指派 student 角色',
  EXISTS (SELECT 1 FROM user_roles WHERE user_id = 'a0000000-0000-0000-0000-000000000001' AND role = 'student')
);
SELECT pg_temp.assert(
  'Email 註冊的管理員自動建立 profiles 列，phone 為 NULL',
  EXISTS (SELECT 1 FROM profiles WHERE id = 'b0000000-0000-0000-0000-000000000099' AND phone IS NULL)
);
SELECT pg_temp.assert(
  'Email 註冊不會自動被指派 student 角色（避免誤判管理員身份）',
  NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = 'b0000000-0000-0000-0000-000000000099' AND role = 'student')
);

-- ===========================================================================
-- 2. fn_class_remaining_seats
-- ===========================================================================
SELECT pg_temp.assert(
  '尚無報名時，剩餘名額等於 capacity',
  (SELECT fn_class_remaining_seats('e0000000-0000-0000-0000-000000000001')) = 10
);
SELECT pg_temp.assert(
  '容量 1 的班級尚無報名時，剩餘名額為 1',
  (SELECT fn_class_remaining_seats('e0000000-0000-0000-0000-000000000004')) = 1
);

-- ===========================================================================
-- 3. rpc_submit_full_term_registrations — happy path（跨場地拆單）
-- ===========================================================================
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000001'::uuid, 'e0000000-0000-0000-0000-000000000002'::uuid],
    'idem-key-student-a-001'
  );
  PERFORM pg_temp.assert('Student A 一次報名兩堂跨場地期課應成功', (v_result->>'success')::boolean = true);
  PERFORM pg_temp.assert('Student A 的報名結果應建立 2 筆 registration_ids', jsonb_array_length(v_result->'registration_ids') = 2);
  PERFORM pg_temp.assert('Student A 跨場地報名應拆成 2 筆 orders', jsonb_array_length(v_result->'order_ids') = 2);
END $$;

RESET ROLE;

SELECT pg_temp.assert(
  '資料庫中確實有 2 筆 Student A 的 active registrations',
  (SELECT COUNT(*) FROM registrations WHERE student_id = 'a0000000-0000-0000-0000-000000000001' AND status = 'active') = 2
);
SELECT pg_temp.assert(
  '資料庫中確實有 2 筆 orders（因跨場地拆單）',
  (SELECT COUNT(*) FROM orders WHERE student_id = 'a0000000-0000-0000-0000-000000000001') = 2
);
SELECT pg_temp.assert(
  'orders 的 total_amount 為伺服器端計算的價格快照，非 0',
  (SELECT COUNT(*) FROM orders WHERE student_id = 'a0000000-0000-0000-0000-000000000001' AND total_amount > 0) = 2
);
SELECT pg_temp.assert(
  '每筆報名都寫入了 audit_logs',
  (SELECT COUNT(*) FROM audit_logs WHERE actor_id = 'a0000000-0000-0000-0000-000000000001' AND action = 'registration_create') = 2
);

-- ===========================================================================
-- 4. Idempotency：同一把 key 重送
-- ===========================================================================
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000001'::uuid, 'e0000000-0000-0000-0000-000000000002'::uuid],
    'idem-key-student-a-001'  -- 同一把 key
  );
  PERFORM pg_temp.assert('同一把 idempotency key 重送應回傳先前結果', (v_result->>'success')::boolean = true);
END $$;

RESET ROLE;

SELECT pg_temp.assert(
  '重送同一把 key 不應建立重複的 registrations（仍然只有 2 筆）',
  (SELECT COUNT(*) FROM registrations WHERE student_id = 'a0000000-0000-0000-0000-000000000001' AND status = 'active') = 2
);

-- ===========================================================================
-- 5. 失敗情境（all-or-nothing：任何一堂失敗，整批都不建立）
-- ===========================================================================

-- 5.1 重複報名（Student A 對已報名的班級再報一次，混合一堂新的班級）
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000001'::uuid, 'e0000000-0000-0000-0000-000000000004'::uuid],
    'idem-key-student-a-002'
  );
  PERFORM pg_temp.assert('混合已報名班級應整批失敗', (v_result->>'success')::boolean = false);
  PERFORM pg_temp.assert('失敗原因應包含 already_registered', EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_result->'failures') f WHERE f->>'reason' = 'already_registered'
  ));
END $$;

RESET ROLE;

SELECT pg_temp.assert(
  'all-or-nothing：失敗時，原本應該成功的那堂課（容量1的班）不應被建立',
  NOT EXISTS (SELECT 1 FROM registrations WHERE student_id = 'a0000000-0000-0000-0000-000000000001' AND class_id = 'e0000000-0000-0000-0000-000000000004')
);

-- 5.2 未開放報名
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000002';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000003'::uuid],
    'idem-key-student-b-001'
  );
  PERFORM pg_temp.assert('未開放報名的班級應失敗', (v_result->>'success')::boolean = false);
  PERFORM pg_temp.assert('失敗原因應為 not_open', EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_result->'failures') f WHERE f->>'reason' = 'not_open'
  ));
END $$;

RESET ROLE;

-- 5.3 額滿（先讓 Student B 報走容量1的班，Student C 再報應該失敗）
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000002';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000004'::uuid],
    'idem-key-student-b-002'
  );
  PERFORM pg_temp.assert('Student B 報名容量1的班應成功（第一位）', (v_result->>'success')::boolean = true);
END $$;

RESET ROLE;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000003';

DO $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := rpc_submit_full_term_registrations(
    ARRAY['e0000000-0000-0000-0000-000000000004'::uuid],
    'idem-key-student-c-001'
  );
  PERFORM pg_temp.assert('Student C 報名已額滿的班應失敗', (v_result->>'success')::boolean = false);
  PERFORM pg_temp.assert('失敗原因應為 full', EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_result->'failures') f WHERE f->>'reason' = 'full'
  ));
END $$;

RESET ROLE;

-- ===========================================================================
-- 6. RLS：Student A 看不到 Student B 的 orders/registrations，Admin 都能看到
-- ===========================================================================
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';

SELECT pg_temp.assert(
  'Student A 只能看到自己的 registrations',
  (SELECT COUNT(*) FROM registrations) = (SELECT COUNT(*) FROM registrations WHERE student_id = 'a0000000-0000-0000-0000-000000000001')
);
SELECT pg_temp.assert(
  'Student A 看不到 Student B 的 orders',
  NOT EXISTS (SELECT 1 FROM orders WHERE student_id = 'a0000000-0000-0000-0000-000000000002')
);

RESET ROLE;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'b0000000-0000-0000-0000-000000000099';

SELECT pg_temp.assert(
  'Admin 可以看到所有學生的 registrations',
  (SELECT COUNT(*) FROM registrations) = 3  -- Student A x2（e001,e002）+ Student B x1（e004）
);
SELECT pg_temp.assert(
  'Admin 可以看到所有學生的 orders',
  (SELECT COUNT(*) FROM orders) >= 3
);

RESET ROLE;

-- Anon（未登入）完全看不到任何 orders/registrations
SET LOCAL ROLE anon;

SELECT pg_temp.assert(
  '匿名使用者看不到任何 orders',
  (SELECT COUNT(*) FROM orders) = 0
);
SELECT pg_temp.assert(
  '匿名使用者看不到任何 registrations',
  (SELECT COUNT(*) FROM registrations) = 0
);
SELECT pg_temp.assert(
  '匿名使用者仍可呼叫 fn_class_remaining_seats（公開名額資訊）',
  (SELECT fn_class_remaining_seats('e0000000-0000-0000-0000-000000000002')) IS NOT NULL
);

RESET ROLE;

-- 匿名/一般登入使用者不能直接寫入 orders/registrations（只能透過 RPC）
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'a0000000-0000-0000-0000-000000000001';

DO $$
BEGIN
  BEGIN
    INSERT INTO registrations (student_id, class_id, term_id, order_id, registration_type, status)
    VALUES ('a0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002',
            'd0000000-0000-0000-0000-000000000002',
            (SELECT id FROM orders LIMIT 1), 'full_term', 'active');
    PERFORM pg_temp.assert('一般使用者不應能直接 INSERT registrations（未觸發例外代表 RLS 失效）', false);
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.assert('一般使用者無法繞過 RPC 直接 INSERT registrations（RLS 正確擋下）', true);
  END;
END $$;

RESET ROLE;

-- ===========================================================================
-- 7. trg_registrations_check_class_term（資料完整性保護，以 postgres 身份直接測試）
-- ===========================================================================
DO $$
BEGIN
  BEGIN
    INSERT INTO registrations (student_id, class_id, term_id, order_id, registration_type, status)
    VALUES (
      'a0000000-0000-0000-0000-000000000001',
      'e0000000-0000-0000-0000-000000000001',              -- 屬於 term d...001
      'd0000000-0000-0000-0000-000000000002',              -- 故意填錯 term（屬於教室B）
      (SELECT id FROM orders LIMIT 1), 'full_term', 'active'
    );
    PERFORM pg_temp.assert('term_id 與 class 實際所屬 term 不一致時應被拒絕（未觸發例外代表保護失效）', false);
  EXCEPTION WHEN check_violation OR others THEN
    PERFORM pg_temp.assert('term_id 與 class 實際所屬 term 不一致時，trg_registrations_check_class_term 正確擋下', true);
  END;
END $$;

-- ===========================================================================
-- 總結
-- ===========================================================================
DO $$
DECLARE
  v_total int;
  v_failed int;
BEGIN
  SELECT COUNT(*), COUNT(*) FILTER (WHERE NOT passed) INTO v_total, v_failed FROM _test_results;
  RAISE NOTICE '=== Registration MVP P0 測試總結：% / % 通過（失敗 %） ===', (v_total - v_failed), v_total, v_failed;
  IF v_failed > 0 THEN
    RAISE EXCEPTION '% 項測試失敗，詳見上方 WARNING', v_failed;
  END IF;
END $$;

ROLLBACK;
