-- Phase 2 — Database Foundation
-- supabase/tests/phase2_rls_manual_check.sql
--
-- 用途：Phase 2 沒有任何業務 RPC，本檔案針對 Schema 本身與 RLS 政策做
-- 「建立後即測」的驗證（呼應 PHASE_0_AUDIT_REPORT.md 第 8.3 節高風險測試
-- 清單第 8 項「RLS：Student A 不能讀取 Student B 的資料」，該項標註
-- 「建立 RLS 後即測」，Phase 2 就是第一次有 RLS 政策可測的時間點）。
--
-- 執行方式：
--   supabase start        -- 啟動本機 Supabase（含真正的 auth schema）
--   supabase db reset     -- 套用 supabase/migrations/ 下所有 migration
--   psql "$(supabase status -o env | grep DB_URL | cut -d= -f2)" \
--        -f supabase/tests/phase2_rls_manual_check.sql
--
-- 本檔案不使用 pgTAP，而是用純 PL/pgSQL DO block + RAISE NOTICE 自製最小
-- 斷言框架，好處是不需要額外安裝 pgTAP extension，任何有 psql 的環境都能
-- 直接執行。每個斷言失敗時仍會 RAISE NOTICE 'FAIL: ...' 讓其餘測試繼續
-- 執行，並在最後統一以總結果數決定整份腳本是否以非 0 狀態結束
-- （最後一個 DO block 用 RAISE EXCEPTION 讓 psql -v ON_ERROR_STOP=1
--   能夠正確回報失敗）。

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. 最小斷言框架
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE _test_results (description text, passed boolean);
-- 測試過程會用 SET LOCAL role 切換到 anon/authenticated 執行查詢，
-- 這兩個角色需要能寫入這張暫存結果表（否則不是 RLS 擋下查詢，
-- 而是單純沒有這張暫存表的權限，會誤判成別的錯誤）。
GRANT INSERT, SELECT ON _test_results TO anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.assert(p_description text, p_condition boolean)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO _test_results VALUES (p_description, COALESCE(p_condition, false));
  IF COALESCE(p_condition, false) THEN
    RAISE NOTICE 'PASS: %', p_description;
  ELSE
    RAISE WARNING 'FAIL: %', p_description;
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 1. 測試資料準備（以 postgres 超級使用者身份，天然略過 RLS）
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_admin_id     uuid := '00000000-0000-0000-0000-000000000001';
  v_student_a_id uuid := '00000000-0000-0000-0000-000000000002';
  v_student_b_id uuid := '00000000-0000-0000-0000-000000000003';
BEGIN
  INSERT INTO auth.users (id, phone) VALUES
    (v_admin_id, '+886900000001'),
    (v_student_a_id, '+886900000002'),
    (v_student_b_id, '+886900000003');

  INSERT INTO public.profiles (id, phone, name) VALUES
    (v_admin_id, '+886900000001', 'Admin One'),
    (v_student_a_id, '+886900000002', 'Student A'),
    (v_student_b_id, '+886900000003', 'Student B');

  INSERT INTO public.user_roles (user_id, role) VALUES
    (v_admin_id, 'admin'),
    (v_student_a_id, 'student'),
    (v_student_b_id, 'student');
END $$;

-- 一公開、一非公開場地；一堂公開課、一堂非公開課
INSERT INTO public.venues (id, name, business_mode, is_active, is_public) VALUES
  ('10000000-0000-0000-0000-000000000001', 'Public Studio', 'self_operated', true, true),
  ('10000000-0000-0000-0000-000000000002', 'Private Studio', 'self_operated', true, false);

INSERT INTO public.terms (id, venue_id, name, start_date, end_date) VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Public Term', '2026-09-01', '2026-10-31'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Private Term', '2026-09-01', '2026-10-31');

INSERT INTO public.classes (id, venue_id, term_id, name, weekdays, start_time, end_time, capacity, business_mode) VALUES
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'Public Zumba', ARRAY[1,3], '19:00', '20:00', 20, 'self_operated'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'Private Zumba', ARRAY[2,4], '19:00', '20:00', 20, 'self_operated');

INSERT INTO public.class_sessions (id, class_id, session_date, start_at, end_at) VALUES
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '2026-09-08', '2026-09-08 19:00+08', '2026-09-08 20:00+08'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '2026-09-09', '2026-09-09 19:00+08', '2026-09-09 20:00+08');

-- ---------------------------------------------------------------------------
-- 2. 匿名使用者（anon，未登入）：公開瀏覽測試
-- ---------------------------------------------------------------------------
SET LOCAL role = anon;
RESET request.jwt.claim.sub;

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'anon 可以看到公開場地',
    (SELECT count(*) FROM public.venues WHERE id = '10000000-0000-0000-0000-000000000001') = 1
  );
  PERFORM pg_temp.assert(
    'anon 看不到非公開場地',
    (SELECT count(*) FROM public.venues WHERE id = '10000000-0000-0000-0000-000000000002') = 0
  );
  PERFORM pg_temp.assert(
    'anon 可以看到公開場地底下的期別',
    (SELECT count(*) FROM public.terms WHERE id = '20000000-0000-0000-0000-000000000001') = 1
  );
  PERFORM pg_temp.assert(
    'anon 看不到非公開場地底下的期別',
    (SELECT count(*) FROM public.terms WHERE id = '20000000-0000-0000-0000-000000000002') = 0
  );
  PERFORM pg_temp.assert(
    'anon 可以看到公開場地底下的班級',
    (SELECT count(*) FROM public.classes WHERE id = '30000000-0000-0000-0000-000000000001') = 1
  );
  PERFORM pg_temp.assert(
    'anon 看不到非公開場地底下的班級',
    (SELECT count(*) FROM public.classes WHERE id = '30000000-0000-0000-0000-000000000002') = 0
  );
  PERFORM pg_temp.assert(
    'anon 可以看到公開班級底下的課堂',
    (SELECT count(*) FROM public.class_sessions WHERE id = '40000000-0000-0000-0000-000000000001') = 1
  );
  PERFORM pg_temp.assert(
    'anon 看不到非公開班級底下的課堂',
    (SELECT count(*) FROM public.class_sessions WHERE id = '40000000-0000-0000-0000-000000000002') = 0
  );
  PERFORM pg_temp.assert(
    'anon 看不到任何 profiles（沒有 SELECT 政策授權給 anon）',
    (SELECT count(*) FROM public.profiles) = 0
  );
  PERFORM pg_temp.assert(
    'anon 看不到任何 audit_logs',
    (SELECT count(*) FROM public.audit_logs) = 0
  );
END $$;

-- ---------------------------------------------------------------------------
-- 3. Student A：只能看到／修改自己的資料，不能碰 Student B 的資料
-- ---------------------------------------------------------------------------
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Student A 可以看到自己的 profile',
    (SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') = 1
  );
  PERFORM pg_temp.assert(
    'Student A 看不到 Student B 的 profile（第 8 項高風險測試：RLS 隔離）',
    (SELECT count(*) FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000003') = 0
  );
  PERFORM pg_temp.assert(
    'Student A 可以看到自己的角色',
    (SELECT count(*) FROM public.user_roles WHERE user_id = '00000000-0000-0000-0000-000000000002') = 1
  );
  PERFORM pg_temp.assert(
    'Student A 看不到 Student B 的角色',
    (SELECT count(*) FROM public.user_roles WHERE user_id = '00000000-0000-0000-0000-000000000003') = 0
  );
END $$;

-- Student A 可以更新自己的 line_id / remit_last5
UPDATE public.profiles SET line_id = 'student_a_line', remit_last5 = '12345'
WHERE id = '00000000-0000-0000-0000-000000000002';

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Student A 可以更新自己的 line_id',
    (SELECT line_id FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') = 'student_a_line'
  );
END $$;

-- Student A 嘗試更新自己的 phone 應該被 trigger 擋下
DO $$
BEGIN
  BEGIN
    UPDATE public.profiles SET phone = '+886900099999'
    WHERE id = '00000000-0000-0000-0000-000000000002';
    PERFORM pg_temp.assert('Student A 不能修改自己的 phone（應被 trigger 擋下）', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('Student A 不能修改自己的 phone（應被 trigger 擋下）', true);
  END;
END $$;

-- Student A 嘗試更新 Student B 的 profile：RLS 應該讓這個 UPDATE 影響 0 列
DO $$
DECLARE
  v_rowcount int;
BEGIN
  UPDATE public.profiles SET line_id = 'hacked'
  WHERE id = '00000000-0000-0000-0000-000000000003';
  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  PERFORM pg_temp.assert('Student A 無法更新 Student B 的 profile（RLS 應影響 0 列）', v_rowcount = 0);
END $$;

-- Student A 嘗試把自己的角色改成 admin：RLS 應該讓這個 UPDATE 影響 0 列（不開放自助升級）
DO $$
DECLARE
  v_rowcount int;
BEGIN
  UPDATE public.user_roles SET role = 'admin'
  WHERE user_id = '00000000-0000-0000-0000-000000000002' AND role = 'student';
  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  PERFORM pg_temp.assert('Student A 無法把自己的角色改成 admin（不開放自助升級）', v_rowcount = 0);
END $$;

-- Student A 可以新增自己的 idempotency key，不能用別人的 user_id
INSERT INTO public.idempotency_keys (key, user_id, action_type, expires_at)
VALUES ('idem-a-1', '00000000-0000-0000-0000-000000000002', 'test_action', now() + interval '1 hour');

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Student A 可以新增自己的 idempotency key',
    (SELECT count(*) FROM public.idempotency_keys WHERE key = 'idem-a-1') = 1
  );
END $$;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.idempotency_keys (key, user_id, action_type, expires_at)
    VALUES ('idem-a-2', '00000000-0000-0000-0000-000000000003', 'test_action', now() + interval '1 hour');
    PERFORM pg_temp.assert('Student A 不能用 Student B 的 user_id 新增 idempotency key', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('Student A 不能用 Student B 的 user_id 新增 idempotency key', true);
  END;
END $$;

-- Student A 看不到 Student B 的 idempotency key
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
INSERT INTO public.idempotency_keys (key, user_id, action_type, expires_at)
VALUES ('idem-b-1', '00000000-0000-0000-0000-000000000003', 'test_action', now() + interval '1 hour');
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Student A 看不到 Student B 的 idempotency key',
    (SELECT count(*) FROM public.idempotency_keys WHERE key = 'idem-b-1') = 0
  );
END $$;

-- Student A（非管理員）看不到 audit_logs、無法直接寫入 audit_logs
DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Student A 看不到 audit_logs（僅管理員可 SELECT）',
    (SELECT count(*) FROM public.audit_logs) = 0
  );
END $$;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.audit_logs (action, entity_type) VALUES ('test', 'test');
    PERFORM pg_temp.assert('Student A 無法直接 INSERT audit_logs（未開放任何角色直接寫入）', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('Student A 無法直接 INSERT audit_logs（未開放任何角色直接寫入）', true);
  END;
END $$;

-- Student A（非管理員）無法新增場地/期別/班級/課堂
DO $$
BEGIN
  BEGIN
    INSERT INTO public.venues (name, business_mode) VALUES ('Hacked Venue', 'self_operated');
    PERFORM pg_temp.assert('Student A 無法新增場地（僅管理員）', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('Student A 無法新增場地（僅管理員）', true);
  END;
END $$;

-- ---------------------------------------------------------------------------
-- 4. Admin：可以看到所有人的資料、可以管理主檔
-- ---------------------------------------------------------------------------
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Admin 可以看到所有 profiles',
    (SELECT count(*) FROM public.profiles) = 3
  );
  PERFORM pg_temp.assert(
    'Admin 可以看到非公開場地',
    (SELECT count(*) FROM public.venues WHERE id = '10000000-0000-0000-0000-000000000002') = 1
  );
  PERFORM pg_temp.assert(
    'Admin 可以看到所有 audit_logs（目前應為 0 筆，因為還沒有任何寫入成功）',
    (SELECT count(*) FROM public.audit_logs) = 0
  );
END $$;

-- Admin 可以修改 Student A 的 phone（trigger 允許管理員例外）
UPDATE public.profiles SET phone = '+886900099999'
WHERE id = '00000000-0000-0000-0000-000000000002';

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Admin 可以修改 Student A 的 phone（管理員例外）',
    (SELECT phone FROM public.profiles WHERE id = '00000000-0000-0000-0000-000000000002') = '+886900099999'
  );
END $$;

-- Admin 可以新增場地、新增管理員角色
INSERT INTO public.venues (id, name, business_mode) VALUES
  ('10000000-0000-0000-0000-000000000099', 'Admin Created Venue', 'external_center');

DO $$
BEGIN
  PERFORM pg_temp.assert(
    'Admin 可以新增場地',
    (SELECT count(*) FROM public.venues WHERE id = '10000000-0000-0000-0000-000000000099') = 1
  );
END $$;

-- ---------------------------------------------------------------------------
-- 5. 資料完整性測試（classes.venue_id 必須與 term 所屬 venue 一致；weekdays 合法）
-- ---------------------------------------------------------------------------
RESET role;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.classes (venue_id, term_id, name, weekdays, start_time, end_time, capacity, business_mode)
    VALUES (
      '10000000-0000-0000-0000-000000000002', -- Private Studio
      '20000000-0000-0000-0000-000000000001', -- 但這個 term 其實屬於 Public Studio
      'Mismatched Class', ARRAY[1], '19:00', '20:00', 10, 'self_operated'
    );
    PERFORM pg_temp.assert('classes.venue_id 與 term 所屬 venue 不一致時應被 trigger 擋下', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('classes.venue_id 與 term 所屬 venue 不一致時應被 trigger 擋下', true);
  END;
END $$;

DO $$
BEGIN
  BEGIN
    INSERT INTO public.classes (venue_id, term_id, name, weekdays, start_time, end_time, capacity, business_mode)
    VALUES (
      '10000000-0000-0000-0000-000000000001',
      '20000000-0000-0000-0000-000000000001',
      'Bad Weekday Class', ARRAY[7], '19:00', '20:00', 10, 'self_operated'
    );
    PERFORM pg_temp.assert('weekdays 超出 0-6 範圍時應被 CHECK 約束擋下', false);
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_temp.assert('weekdays 超出 0-6 範圍時應被 CHECK 約束擋下', true);
  END;
END $$;

-- ---------------------------------------------------------------------------
-- 6. 總結
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_total  int;
  v_passed int;
  v_failed int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE passed), count(*) FILTER (WHERE NOT passed)
  INTO v_total, v_passed, v_failed
  FROM _test_results;

  RAISE NOTICE '=== Phase 2 RLS 測試總結：% / % 通過（失敗 %） ===', v_passed, v_total, v_failed;

  IF v_failed > 0 THEN
    RAISE EXCEPTION '有 % 項測試失敗，請見上方 FAIL 訊息', v_failed;
  END IF;
END $$;

ROLLBACK;
