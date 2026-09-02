-- Registration MVP — P0 初始資料 Seed Script
--
-- 用途：REGISTRATION_MVP_PLAN.md 第 A/D 節已確認，第一版不做完整 Admin
-- CRUD 表單，改用這份 SQL Script 直接建立你要開放報名的場地／期別／班級。
-- 這不是 migration（不會被放進 supabase/migrations/，不會被
-- `supabase db reset` 自動套用），需要你自己手動執行一次。
--
-- 使用方式（擇一，兩種都可以直接執行以下全部內容，不需要額外工具）：
--   A. Supabase Studio → SQL Editor，貼上整份內容，改好下方「請依實際情況
--      修改」區塊的值後執行。
--   B. 本機用 psql 或 `npx supabase db execute -f
--      supabase/seed/registration_mvp_seed.sql` 執行。
--
-- 執行前請先確認：資料庫已經套用到最新的 migration（含
-- 20260902100008_registration_rpc.sql），也就是 Phase 2 + Registration MVP
-- 的所有 migration 都已經跑過 `supabase db reset` 或已部署到你的正式專案。

-- ===========================================================================
-- 1. 建立第一位管理員（Bootstrap）
-- ===========================================================================
-- 這個腳本本身不會幫你建立 Supabase Auth 帳號（需要用 Email+Password 透過
-- Supabase Studio 的 Authentication 頁面手動建立，或用 Service Role 呼叫
-- auth.admin.createUser）。建立帳號後，Trigger 會自動幫你建立 profiles 列，
-- 但 admin 角色一定要手動指派（Phase 2 migration 已記錄的 bootstrap
-- 流程，避免自助升級風險）。
--
-- 步驟：
--   1. Supabase Studio → Authentication → Add user，用 Email+Password 建立
--      你自己的管理員帳號，記下建立後的 User UID。
--   2. 把下面這行的 'PASTE-ADMIN-AUTH-USER-UID-HERE' 換成剛剛的 UID，取消
--      註解後執行：
--
-- INSERT INTO public.user_roles (user_id, role)
-- VALUES ('PASTE-ADMIN-AUTH-USER-UID-HERE', 'admin');

-- ===========================================================================
-- 2-4. 場地／期別／班級 —— 請依實際情況修改下面 DECLARE 區塊與 INSERT 內容
-- 全部包在同一個 DO 區塊內，確保場地/期別/班級是同一批一起建立、彼此的
-- 外鍵關聯正確（不需要手動複製貼上 id）。
-- ===========================================================================
DO $$
DECLARE
  v_venue_id uuid;
  v_term_id  uuid;
BEGIN
  INSERT INTO public.venues (id, name, address, business_mode, is_active, is_public)
  VALUES (
    gen_random_uuid(),
    '請填入場地名稱（例如：○○舞蹈教室）',
    '請填入完整地址',
    'self_operated',
    true,
    true
  )
  RETURNING id INTO v_venue_id;

  INSERT INTO public.terms (id, venue_id, name, start_date, end_date, is_active)
  VALUES (
    gen_random_uuid(),
    v_venue_id,
    '請填入期別名稱（例如：2026 年 9-10 月秋季班）',
    '2026-09-01',  -- 請改成實際開課日期
    '2026-12-01',  -- 請改成實際結束日期
    true
  )
  RETURNING id INTO v_term_id;

  -- weekdays：0=週日 1=週一 2=週二 3=週三 4=週四 5=週五 6=週六
  -- capacity：這堂課的人數上限（期課報名名額依此欄位計算）
  -- is_open_for_registration：設為 true 才會出現在學生的公開瀏覽頁
  -- 請依實際課程增減以下列數：
  INSERT INTO public.classes (
    id, venue_id, term_id, name, weekdays, start_time, end_time,
    capacity, business_mode, full_term_price, is_open_for_registration, is_active
  ) VALUES
    (gen_random_uuid(), v_venue_id, v_term_id, '爵士舞初階', ARRAY[1], '19:00', '20:00', 15, 'self_operated', 3000, true, true),
    (gen_random_uuid(), v_venue_id, v_term_id, 'KPOP 舞蹈',   ARRAY[3], '19:00', '20:00', 15, 'self_operated', 3200, true, true),
    (gen_random_uuid(), v_venue_id, v_term_id, '女子舞蹈',    ARRAY[5], '19:00', '20:00', 15, 'self_operated', 3000, true, true);

  RAISE NOTICE '建立完成：venue_id=%, term_id=%（詳細內容請看下方驗證查詢結果）', v_venue_id, v_term_id;
END $$;

-- ===========================================================================
-- 5. 驗證：列出最近一分鐘內建立的班級（Studio 與 psql 皆可直接看到這個結果表）
-- ===========================================================================
SELECT c.name, v.name AS venue, t.name AS term, c.capacity, c.full_term_price, c.is_open_for_registration
FROM public.classes c
JOIN public.venues v ON v.id = c.venue_id
JOIN public.terms t ON t.id = c.term_id
WHERE c.created_at > now() - interval '1 minute'
ORDER BY c.created_at DESC;
