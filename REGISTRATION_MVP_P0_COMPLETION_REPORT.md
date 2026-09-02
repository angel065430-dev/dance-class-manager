# REGISTRATION_MVP_P0_COMPLETION_REPORT.md

# Registration MVP — P0 完成報告

> **狀態：✅ P0 核心路徑已實作並在雲端沙盒完成能自行驗證的部分（DB 層：真實執行；前端：無法在此環境執行 npm/瀏覽器，需要你在本機做最後一輪驗收）。**
> 依 `REGISTRATION_MVP_PLAN.md` 你已確認的四點結論實作，範圍：學生登入／註冊、公開課程瀏覽、一次選擇一堂或多堂期課並原子性送出報名、管理員登入與報名清單唯讀頁、Seed Script。**尚未標記為最終完成**——比照 Phase 1/2 的模式，需要你在本機跑過驗收後才正式收尾。

---

## 0. Inspect（開始前）

以 `REGISTRATION_MVP_PLAN.md` 已確認的四點結論為準：`profiles.phone` 改 nullable、P0/P1/P2 範圍、多堂報名採全部成功或全部失敗、Admin CRUD 延後到 P1（Seed Script 頂替）。Phase 2 的 8 張表與 RLS 基礎維持不動，本輪只新增，不修改既有 migration 檔案。

---

## 1. Implement（完成項目）

### 1.1 資料庫（3 個新 migration，接續 Phase 2 的檔名序號）

| Migration | 內容 |
|---|---|
| `20260902100006_auth_provisioning.sql` | `profiles.phone` 改 nullable；`handle_new_auth_user()` + `auth.users` 的 `AFTER INSERT` Trigger——手機註冊自動建立 `profiles` + `student` 角色，Email 註冊只建立 `profiles`（phone=NULL），不自動給角色 |
| `20260902100007_orders_and_registrations.sql` | 新增 `orders`／`registrations` 兩張表（MVP 瘦身版，`registration_type`/`class_session_id` 保留單堂擴充能力）+ 防重複報名的 Partial Unique Index + RLS（本人或 Admin 可 SELECT，無任何角色可直接寫入）+ `trg_registrations_check_class_term` 資料完整性保護 |
| `20260902100008_registration_rpc.sql` | `fn_class_remaining_seats()`（公開名額查詢）+ `rpc_submit_full_term_registrations()`（原子性多堂報名 RPC，全部成功或全部失敗，含併發鎖定、Idempotency、多場地拆單、稽核紀錄） |

### 1.2 前端

* `src/utils/phone.ts`、`src/utils/pin.ts`：電話正規化、PIN 前端封鎖規則（弱 PIN 的伺服器端強制封鎖列入 P1，見第 5 節）。
* `src/composables/useAuth.ts`：學生 Phone+PIN 註冊/登入、管理員 Email+Password 登入、全域登入狀態與角色（僅供 UI 導引使用，非安全邊界）。
* `src/services/classes.ts`、`src/services/registrations.ts`：封裝 Supabase 查詢／RPC 呼叫（沿用 `PHASE_0_AUDIT_REPORT.md` 第 4.1 節建議的 Services 分層）。
* `src/types/database.ts`：手寫型別（尚未有真正 Supabase 專案可執行 `supabase gen types`，見第 5 節）。
* 頁面：`student/{LoginView,RegisterView,CoursesView,MyRegistrationsView}.vue`、`admin/{AdminLoginView,AdminRegistrationsView}.vue`、更新後的 `HomeView.vue`、`AppShell.vue`（加上導覽列）、`App.vue`（啟動時初始化登入狀態）。
* `src/router/index.ts` + `route-meta.d.ts`：新增路由與最小守衛（UX 便利性，非安全邊界）。

### 1.3 測試與 Seed

* `supabase/tests/registration_mvp_manual_check.sql`：Provisioning Trigger／RLS／`fn_class_remaining_seats`／RPC happy path／all-or-nothing 失敗情境／Idempotency／資料完整性保護，共 32 項斷言。
* `supabase/seed/registration_mvp_seed.sql`：Admin bootstrap 說明 + 場地/期別/班級建立範本（取代 P0 的 Admin CRUD 表單）。
* `tests/unit/{phone,pin}.spec.ts`：新增。`tests/unit/{AppShell,router}.spec.ts`：因元件行為變更而更新。
* `e2e/registration-mvp.spec.ts`：學生註冊 → 瀏覽 → 多選 → 送出 → 確認的完整 happy path。

---

## 2. Validate（驗證結果）

### 2.1 我在雲端沙盒「實際執行」並親眼確認的部分（資料庫層）

沿用 Phase 2 已驗證的做法：本機 PostgreSQL 16 + 手動建立的 `auth` schema／`auth.uid()`／`anon`/`authenticated`/`service_role` 模擬 Supabase 形狀，這不是真正的 Supabase Local，但可以對 migration 本身、RLS、RPC 邏輯做真實的 DDL/DML 執行驗證（而不是只憑閱讀程式碼判斷）。

| 項目 | 方法 | 結果 |
|---|---|---|
| 8 個 migration 從乾淨環境依序套用 | `DROP SCHEMA public CASCADE` 後重新套用全部 migration | ✅ 成功，**獨立做了兩次**（一次搭配功能測試、一次搭配併發測試用的全新資料庫），確認可重現 |
| 功能／RLS／資料完整性測試 | `supabase/tests/registration_mvp_manual_check.sql`，32 項斷言，`BEGIN...ROLLBACK` 不留測試資料 | ✅ **32 / 32 通過** |
| **多人同時搶最後一個名額**（你要求不可省略） | 5 個**真正獨立的資料庫連線**（背景 shell process）同時對容量 1 的班級呼叫 `rpc_submit_full_term_registrations` | ✅ 恰好 1 位成功、4 位收到 `full`，資料庫實際只留下 1 筆 `registrations`，**沒有超賣** |
| Idempotency 併發（兩個併發請求同時用同一把全新 key） | 2 個真正獨立連線同時呼叫同一把從未出現過的 idempotency key | ✅ 兩邊都拿到同一個 `registration_id`，資料庫只留下 1 筆 `registrations`（驗證了 upsert-with-retry 邏輯正確處理了「同時建立 key 列」的競態，而不是只驗證了『key 已存在時』的情況） |
| Seed Script | 在乾淨環境套用全部 migration 後執行 | ✅ 成功建立場地/期別/3 個班級 |

測試涵蓋的關鍵情境：手機註冊→自動建立 `profiles`+`student` 角色；Email 註冊→只建立 `profiles`（phone=NULL）、不自動給角色（驗證上一輪發現並由你確認的方案）；跨場地一次報名自動拆成 2 筆 `orders`；重複報名/未開放/額滿的 all-or-nothing（失敗時完全不建立任何資料，即使批次中有一堂原本會成功）；Student A 看不到 Student B 的 `orders`/`registrations`，Admin 可以看到全部，匿名使用者兩者都看不到但仍可查詢公開名額；一般使用者無法繞過 RPC 直接 `INSERT registrations`（RLS 正確擋下）。

### 2.2 我**無法**在此環境驗證、需要你在本機完成的部分

和 Phase 1/2 相同的根本限制：這個雲端沙盒沒有 npm registry 網路存取（`type-check`/`lint`/`build`/`test:unit`/`test:e2e` 都需要 `node_modules`），也沒有工具可以連上你電腦執行指令或開瀏覽器。以下必須由你在本機執行：

1. `npm install`（如果 `package.json`/`package-lock.json` 本身沒變，理論上不需要重裝，但建議跑一次確認）
2. `npm run format` → `npm run format:check`
3. `npm run type-check`
4. `npm run lint:check`
5. `npm run build`
6. `npm run test:unit`（含新增的 `phone.spec.ts`/`pin.spec.ts`，以及因元件變更而更新的 `AppShell.spec.ts`/`router.spec.ts`）
7. `npx supabase db reset`（套用全部 migration，包含這次新增的 3 個，並確認沒有報錯）
8. 用 `psql` 或 Supabase Studio 執行 `supabase/tests/registration_mvp_manual_check.sql`，確認顯示 `Success. No rows returned` 或等效的「無 EXCEPTION」結果
9. 執行 `supabase/seed/registration_mvp_seed.sql`（改好裡面的場地/班級名稱後）
10. `npm run dev`，實際用瀏覽器走一次：註冊學生 → 瀏覽課程 → 勾選多堂 → 送出 → 確認頁 → 我的報名；另外用 Supabase Studio 建立一個管理員帳號並指派 `admin` 角色後，登入 `/admin/login` 確認能看到報名清單
11. `npm run test:e2e:install` → `npm run test:e2e`（含新增的 `registration-mvp.spec.ts`，需要 (7)(9) 已完成、`npm run dev` 或 `preview` 正在執行）

### 2.3 額外請你在本機順便確認的一項（我在此環境無法查證）

`fetchOpenClasses`/`fetchMyRegistrations`/`fetchAllRegistrationsForAdmin` 使用了 Supabase JS 的巢狀關聯查詢語法（例如 `classes ( name, venues ( name ) )`），這需要真正跑起來的 PostgREST 才能驗證語法/關聯解析完全正確——我的驗證環境是純 PostgreSQL，沒有 PostgREST，無法對這部分做到像 RPC 邏輯那樣的真實執行驗證。我已經依 Supabase 官方文件的巢狀 embed 語法與現有的 FK 關聯（`classes.venue_id`/`classes.term_id`/`registrations.student_id`/`registrations.class_id` 都是單一、不重複的關聯路徑，理論上不會有語法要求的關聯消歧義問題）仔細核對過，但這是唯一一項「我認為正確、但沒有真正執行過」的部分，請在上方 2.2 第 10 步驟實際瀏覽器測試時特別留意這幾個查詢畫面是否正常顯示（班級名稱、場地名稱等），如果 PostgREST 回報關聯消歧義錯誤，請把錯誤訊息貼給我，我會加上明確的 FK hint（例如 `classes!registrations_class_id_fkey`）修正。

---

## 3. Security Considerations

* 所有寫入（`orders`/`registrations`）只能透過 `rpc_submit_full_term_registrations()`（`SECURITY DEFINER`）完成，RLS 對 `anon`/`authenticated` 沒有開放任何直接 `INSERT`/`UPDATE`/`DELETE` 政策，已用測試驗證繞過 RPC 直接寫入會被擋下。
* 名額檢查在同一交易內對 `classes` 列做 `SELECT ... FOR UPDATE`，依 `class_id` 排序鎖定避免 deadlock，已用真正的併發連線測試證明不會超賣。
* Idempotency 沿用 Phase 2 的 `idempotency_keys` 表，正確處理「兩個請求同時用同一把全新 key」的競態（見 2.1 表格）。
* 每筆報名建立時寫入 `audit_logs`（`AI_INSTRUCTIONS.md` 第 22 節）。
* `profiles.phone` 改為 nullable 後，`UNIQUE` 約束仍然保護學生手機唯一性（Postgres `UNIQUE` 允許多個 `NULL` 並存）。
* Admin 角色維持 Phase 2 已確認的 bootstrap 流程：自助註冊（不論手機或 Email）都不會自動取得 `admin`，一律要由既有管理員或 Service Role 手動指派。
* 前端弱 PIN 封鎖只是第一道防線，**不構成**規格要求的「不可只在前端擋」的伺服器端強制——這是依 `REGISTRATION_MVP_PLAN.md` 已經你確認的 P1 延後項，殘餘風險已在該文件說明。
* 未新增 `failed_login_count`/`locked_until` 欄位（沿用 Phase 2 的判斷：欄位與其安全寫入路徑要一起做，不留欄位存在但沒保護的空窗期）。

---

## 4. Not Implemented（明確列出本輪刻意不做的項目，全部依 `REGISTRATION_MVP_PLAN.md` 已確認的 P1/P2 劃分）

1. 弱 PIN 的伺服器端 Auth Hook 強制封鎖、登入失敗鎖定（`failed_login_count`/`locked_until`）——P1。
2. SMS 首次手機驗證（OTP）——P1，待你之後決定是否啟用。
3. Admin 完整 CRUD（場地/期別/班級管理表單）——P1，本輪以 Seed Script 頂替。
4. 單堂報名 UI/RPC——P1，資料庫已預留 `registration_type`/`class_session_id` 欄位。
5. 付款狀態流程（`payments`、Admin 確認付款）——P1。
6. 半期後停止整期報名的自動判斷——P1，目前需要 Admin 手動把 `is_open_for_registration` 關閉來達到同樣效果。
7. CSV 匯出、Google Calendar 整合、Admin MFA 強制、優惠碼/請假/補課/特別活動/門禁/點名/Realtime——維持原 Roadmap 位置，未受本次調整影響。
8. `supabase gen types typescript`：仍需要真正連上 Supabase 專案才能產生，`src/types/database.ts` 目前是手寫型別。

---

## 5. Recommended Next Step

請依第 2.2 節的 11 個步驟在本機完成驗收（尤其是第 7-8 步的 migration/RLS 測試、第 10 步的實際瀏覽器走一次完整流程、第 11 步的 e2e），並留意第 2.3 節提到的巢狀查詢語法這一項。驗收通過後，麻煩回報結果，我會依 Phase 1/2 的模式把驗收結果補進本報告並正式標記 P0 完成；之後我們再一起看 `REGISTRATION_MVP_PLAN.md` 列的 P1 項目該怎麼排序。在你確認驗收通過之前，我不會開始 P1 的任何項目。

---

# End of REGISTRATION_MVP_P0_COMPLETION_REPORT.md
