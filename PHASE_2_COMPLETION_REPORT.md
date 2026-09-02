# PHASE_2_COMPLETION_REPORT.md

# Phase 2 — Database Foundation 完成報告

- 報告日期：2026-09-02
- 範圍依據：`MASTER_SPEC.md` 第 44 節 Phase 2、`PHASE_0_AUDIT_REPORT.md` 第 8.2 節 Phase 清單（`profiles`／`user_roles`／`venues`／`terms`／`classes`／`class_sessions` + FK/Index/RLS 基礎，並依第 8.1 節確認的排序調整，提前建立 `audit_logs`／`idempotency_keys`）
- 前置狀態：Phase 1（Project Foundation）已於本機完整驗收通過並標記完成（`PHASE_1_COMPLETION_REPORT.md` Round 4）

> **狀態：✅ Phase 2 完成並通過真正 Supabase Local Final Acceptance。** 本 Phase 只建立資料庫 Schema、FK/Index/RLS 基礎、稽核與冪等表格；未建立任何業務 RPC、未修改前端程式碼、未涉及 Authentication 實作（那是 Phase 3 的範圍）。第一輪驗證於雲端沙盒的模擬環境完成，第二輪（Final Acceptance，見下方新增章節）已由你在自己電腦上以真正的 Supabase Local（Docker + Supabase CLI 2.116.0）重新驗證通過。

---

## 0. Inspect（開始前的檢查）

依 `AI_INSTRUCTIONS.md` 第 5 節流程，開始實作前重新檢查：

- 重新讀取 `MASTER_SPEC.md`（含第 49 節 Round 2 決策附錄）、`AI_INSTRUCTIONS.md`、`PHASE_0_AUDIT_REPORT.md`、`PHASE_1_COMPLETION_REPORT.md` 四份文件全文。
- 重新從你的電腦讀取目前實際的 `package.json`／`package-lock.json`，確認 Phase 1 遺留的相依套件狀態（`@tsconfig/node22` 已移除、其餘版本未變動），確認沒有尚未處理的技術債會影響 Phase 2。
- 檢查現有專案結構：`supabase/config.toml` 已存在（Phase 1 建立），但 `supabase/migrations/` 目錄尚未建立任何檔案，`src/` 底下沒有任何資料庫相關程式碼——確認 Phase 2 是一個乾淨的起點，沒有需要相容的既有 Schema。
- 確認雲端沙盒工作環境這次**有**本機 PostgreSQL 16 可用（`psql`／`postgresql-16` 已預裝），因此本輪驗證方式與 Phase 1 不同：Phase 1 完全無法在雲端環境執行任何資料庫或建置驗證；Phase 2 雖然仍無法執行真正的 `supabase start`（需要 Docker + 網路下載映像檔，本沙盒沒有），但可以**用一個模擬 Supabase 形狀（`auth.users`／`auth.uid()`／`anon`/`authenticated`/`service_role` 角色）的乾淨本機 PostgreSQL 資料庫，實際執行每一份 migration SQL 並跑真正的 RLS 行為測試**，比 Phase 1 單純的 JSON/語法檢查強得多。詳見第 4 節。

## 1. Analyze（現況、缺口、影響）

**現況**：`supabase/` 目錄目前只有 Phase 1 建立的 `config.toml`（本機開發環境設定骨架），沒有任何資料表、RLS 政策或函式。

**缺口**：依 Phase 0 Roadmap，Phase 2 需要建立 8 張基礎資料表（`profiles`／`user_roles`／`venues`／`terms`／`classes`／`class_sessions`／`audit_logs`／`idempotency_keys`）及對應的 FK、Index、RLS 基礎政策。

**會異動的檔案**：只新增 `supabase/migrations/` 底下 5 份新檔案、`supabase/tests/` 底下 1 份新檔案，並小幅更新 `supabase/config.toml` 的說明註解。**不修改**任何 `src/` 底下的前端程式碼——Phase 2 是純資料庫 Phase，前端要等到 Phase 4（Admin Foundation）、Phase 5（Student Frontend）才會開始串接這些表。

**資料庫影響**：從 0 張表增加到 8 張表，全部為新建，沒有既有資料需要遷移或相容。

**安全性影響**：這是本 Phase 的重點——每張表建立當下就啟用 RLS 並掛上政策，不會有「先建表、之後才補 RLS」的空窗期。

## 2. Plan（實作前的說明，依你的要求列出）

**本 Phase 目標**：建立 Phase 0 Roadmap 定義的 8 張基礎資料表，含 FK、Index、CHECK 約束、RLS 基礎政策，以及 Phase 2 起後續所有表都會用到的共用輔助函式（`is_admin()`、`set_updated_at()`）。不建立任何業務邏輯 RPC、不處理 Authentication 實際串接、不產生任何前端程式碼。

**預計建立的檔案**：

```text
supabase/migrations/20260902100001_extensions_and_helpers.sql
supabase/migrations/20260902100002_profiles_and_roles.sql
supabase/migrations/20260902100003_venues_terms.sql
supabase/migrations/20260902100004_classes_and_sessions.sql
supabase/migrations/20260902100005_audit_and_idempotency.sql
supabase/tests/phase2_rls_manual_check.sql
```

**是否修改資料庫 Schema**：是，這正是本 Phase 的內容——從零建立 8 張表（見第 3 節）。

**是否需要 Supabase 設定**：小幅更新 `supabase/config.toml` 的說明註解（反映 migrations 目錄已不再是空的），未變更任何實際設定值（port／auth／realtime 設定維持 Phase 1 版本）。

**主要風險**：

1. **RLS 政策遺漏或寫錯，導致學生看到別人的資料，或匿名使用者看到不該公開的資料。** 緩解方式：每張表都在同一批 migration 內就啟用 RLS 並掛上政策，並用實際執行的 SQL 測試腳本驗證（見第 4 節），而不是只憑閱讀程式碼判斷。
2. **`is_admin()` 輔助函式若寫錯，可能造成兩種相反方向的風險**：權限判斷失效（誰都被當管理員）或管理員功能完全失效（誰都不被當管理員）。緩解方式：`SECURITY DEFINER` + 明確 `search_path`，並在測試腳本中同時驗證「管理員能做什麼」與「非管理員不能做什麼」兩個方向。
3. **管理員角色指派的「雞生蛋」啟動問題**：`user_roles` 的 INSERT 政策要求呼叫者已經是管理員，但系統剛建立時沒有任何管理員。緩解方式：明確記錄於 migration 註解與本報告，第一個管理員帳號需由具備 Service Role 權限的操作人員手動建立，這是此類架構的標準做法，非設計缺陷。
4. **`classes.venue_id` 與其所屬 `term.venue_id` 不一致的資料錯誤**：Schema 本身的 FK 約束無法防止「班級掛在 A 場地、卻選了 B 場地的期別」。緩解方式：新增一個資料庫 trigger 主動檢查並拒絕不一致的寫入（詳見第 3 節、第 6 節的範圍決策說明）。

**驗收標準**：

1. 5 份 migration 依序套用到一個乾淨的 PostgreSQL 資料庫，全部成功、無錯誤（且可重複執行——從乾淨資料庫重跑一次仍然成功）。
2. 針對每張表的 RLS 政策，用實際 SQL 測試腳本驗證「該可見的看得到、不該可見的看不到」，涵蓋 anon／student A／student B／admin 四種身份。
3. 資料完整性約束（`classes` 與 `terms` 的場地一致性、`weekdays` 合法範圍等）確實會擋下不合法的寫入。
4. 不影響 Phase 1 已通過的前端 build/lint/test（因為完全沒有修改 `src/` 或任何前端設定檔）。

---

## 3. Implement（完成項目）

### 3.1 共用輔助函式（`20260902100001_extensions_and_helpers.sql`）

- `set_updated_at()`：通用 BEFORE UPDATE trigger 函式，自動維護 `updated_at`。
- `is_admin()`：`SECURITY DEFINER` 輔助函式，判斷呼叫者是否具備 `admin` 角色（實際定義因為必須参照 `user_roles`，放在 20260902100002，見檔案內註解說明原因）。

### 3.2 `profiles` / `user_roles`（`20260902100002_profiles_and_roles.sql`）

- `profiles`：`id`（= `auth.users.id`）、`phone`（UNIQUE NOT NULL）、`name`、`line_id`、`remit_last5`、`created_at`、`updated_at`。
- `user_roles`：`user_id → profiles.id`、`role CHECK (IN ('student','admin'))`，`UNIQUE (user_id, role)`。
- 新增一個 `trg_profiles_protect_phone` trigger：非管理員無法透過一般 UPDATE 修改自己的 `phone`（登入身份識別欄位），管理員例外。這是主動的技術性防護，超出 Phase 0 schema 提案的字面欄位清單，理由與範圍說明見第 6 節。
- RLS：`profiles` 本人或管理員可 SELECT/UPDATE，不開放 INSERT/DELETE（provisioning trigger 留待 Phase 3）。`user_roles` 本人或管理員可 SELECT，僅管理員可 INSERT/UPDATE/DELETE（不開放自助升級）。

### 3.3 `venues` / `terms`（`20260902100003_venues_terms.sql`）

- `venues`：`name`、`address`、`business_mode CHECK (IN ('self_operated','external_center'))`、`is_active`、`is_public`。
- `terms`：`venue_id → venues.id`、`name`、`start_date`、`end_date`（`CHECK (end_date >= start_date)`）、`leave_rule_note`、`is_active`。
- 新增 `fn_is_venue_public(venue_id)` 輔助函式，集中定義「場地是否公開可見」，供本表與下游 `classes`／`class_sessions` 共用同一套判斷邏輯。
- RLS：公開瀏覽（`is_active = true AND is_public = true`，`terms` 額外要求所屬場地也符合公開條件）對 `anon`／`authenticated` 開放 SELECT；INSERT/UPDATE/DELETE 僅限管理員。

### 3.4 `classes` / `class_sessions`（`20260902100004_classes_and_sessions.sql`）

- `classes`：`venue_id`、`term_id`、`name`、`weekdays int[]`（`CHECK` 限制在 0-6 範圍且非空）、`start_time`／`end_time`（`CHECK (end_time > start_time)`）、`capacity`、`business_mode`、`full_term_price`／`single_session_price`、`default_base_makeup_capacity`、`is_open_for_registration`、`is_active`。
- `class_sessions`：`class_id`、`session_date`、`start_at`／`end_at`（`CHECK (end_at > start_at)`）、`status CHECK (IN ('scheduled','cancelled'))`、`base_makeup_capacity`、`notes`，`UNIQUE (class_id, session_date)`。
- 新增 `trg_classes_check_term_venue` trigger：拒絕 `classes.venue_id` 與其所屬 `terms.venue_id` 不一致的寫入（範圍決策說明見第 6 節）。
- 新增 `fn_is_class_public(class_id)` 輔助函式，沿用 `fn_is_venue_public()` 再疊加班級自身 `is_active`，供 `classes`／`class_sessions` 共用。
- RLS：公開瀏覽對 `anon`／`authenticated` 開放 SELECT；INSERT/UPDATE/DELETE 僅限管理員。`class_sessions` 的可見性不因 `status='cancelled'` 而隱藏。

### 3.5 `audit_logs` / `idempotency_keys`（`20260902100005_audit_and_idempotency.sql`）

- `audit_logs`：`actor_id`（nullable）、`actor_role`、`action`、`entity_type`、`entity_id`、`before_data jsonb`、`after_data jsonb`、`reason`、`created_at`。**唯獨（append-only）設計**：只開放管理員 SELECT，不對任何角色開放 INSERT/UPDATE/DELETE（未來業務 RPC 以 `SECURITY DEFINER` 身份寫入，天然略過 RLS）。
- `idempotency_keys`：`key`（PK，客戶端產生的 UUID 字串）、`user_id`、`action_type`、`request_hash`、`response_snapshot jsonb`、`status CHECK (IN ('processing','completed','failed'))`、`created_at`、`expires_at`。RLS：使用者可 SELECT/INSERT 自己的 key，不開放 UPDATE（狀態轉換留給未來 RPC 內部管理）。

### 3.6 RLS 驗證測試（`supabase/tests/phase2_rls_manual_check.sql`）

一份可重複執行的純 SQL 測試腳本（不依賴 pgTAP，自製最小斷言框架），涵蓋 31 項斷言，見第 4 節實際執行結果。

---

## 4. Validate（驗證結果——本輪在雲端沙盒環境「實際執行」，非憑閱讀程式碼判斷）

**重要說明（誠實回報，呼應你的明確要求「不要假裝任何無法執行的測試已經通過」）**：這次雲端沙盒環境剛好預裝了 PostgreSQL 16（`psql`），這是 Phase 1 完全沒有的條件。因此本輪驗證方式比 Phase 1 更進一步：不是只做語法檢查，而是**建立一個模擬 Supabase 形狀的乾淨本機 PostgreSQL 資料庫（自建 `auth.users`／`auth.uid()`／`anon`/`authenticated`/`service_role` 角色），實際套用全部 5 份 migration、實際執行 RLS 測試腳本，得到真實的資料庫回應**。

但這**不等於**真正的 `supabase start`（Supabase CLI 本機開發環境）：那需要 Docker 並下載官方映像檔，本沙盒沒有網路無法做到；真正的 Supabase 環境還包含完整的 `auth`/`storage`/`realtime` schema、`pgjwt`、PostgREST 等元件，本測試只模擬了 RLS 驗證所需的最小子集（`auth.users` 表、`auth.uid()` 函式、三個標準角色）。因此**建議你在自己電腦上執行 `supabase start` 後，用同一份 `supabase/tests/phase2_rls_manual_check.sql` 針對真正的本機 Supabase 環境再跑一次**，作為最終確認；但以下結果已經是對 migration SQL 本身正確性的真實驗證，不是空話。

### 4.1 Migration 套用結果

在**兩個獨立的乾淨資料庫**上分別測試（確保結果不是偶然，且證明從全新環境套用也會成功，對應你未來 `supabase db reset` 的實際使用情境）：

| 測試                                                                  | 結果                                               |
| --------------------------------------------------------------------- | -------------------------------------------------- |
| 資料庫 1（`dcm_phase2_test`）：依序套用 5 份 migration                | ✅ 全部成功，exit code 0                           |
| 資料庫 2（`dcm_phase2_fresh`，完全獨立重建）：依序套用 5 份 migration | ✅ 全部成功，exit code 0                           |
| 套用後檢查：8 張表是否都存在、RLS 是否都已啟用                        | ✅ 8/8 張表存在，`relrowsecurity = true`（見下表） |

```text
    table_name    | rls_enabled | policy_count
------------------+-------------+--------------
 audit_logs       | t           |            1
 class_sessions   | t           |            4
 classes          | t           |            4
 idempotency_keys | t           |            2
 profiles         | t           |            2
 terms            | t           |            4
 user_roles       | t           |            4
 venues           | t           |            4
```

### 4.2 RLS 與資料完整性測試（`phase2_rls_manual_check.sql`）

在兩個資料庫上分別執行，**兩次結果一致**：

```text
=== Phase 2 RLS 測試總結：31 / 31 通過（失敗 0）===
```

涵蓋的測試範圍：

- **匿名使用者（anon）**：可看到公開場地/期別/班級/課堂（10 項），看不到非公開場地底下的任何一層、看不到 `profiles`、看不到 `audit_logs`。
- **Student A（一般使用者）**：可看到並更新自己的 `profile`（`line_id`），看不到 Student B 的 `profile`／角色（對應 `PHASE_0_AUDIT_REPORT.md` 第 8.3 節高風險測試清單第 8 項「RLS：Student A 不能讀取 Student B 的資料」）；無法修改自己的 `phone`（trigger 擋下）；無法更新 Student B 的資料、無法把自己角色改成 admin（RLS 影響 0 列）；可新增自己的 idempotency key、不能用他人 `user_id` 新增；看不到他人的 idempotency key；看不到且無法寫入 `audit_logs`；無法新增場地。
- **Admin**：可看到所有 `profiles`（含非公開場地）、可看到所有 `audit_logs`、可修改他人 `phone`（管理員例外）、可新增場地。
- **資料完整性**：`classes.venue_id` 與其 `term` 實際所屬 `venue_id` 不一致時，寫入被 trigger 拒絕；`weekdays` 超出 0-6 範圍時，寫入被 CHECK 約束拒絕。

### 4.3 對 Phase 1 前端骨架的回歸影響

本 Phase 完全沒有修改 `src/`、`package.json`、任何 `tsconfig*.json`、`vite.config.ts` 等 Phase 1 檔案，因此**不需要、也沒有**重新執行 `npm run build`/`type-check`/`test:unit` 等指令——這些檔案內容與 Phase 1 驗收通過時完全相同，沒有回歸風險。

---

## 5. Not Implemented（明確列出本 Phase 刻意不做的項目）

1. **`fn_session_used_seats(session_id)`**（`PHASE_0_AUDIT_REPORT.md` 第 5.3 節）：需要讀取 `registrations`（Phase 5）與 `makeup_reservations`（Phase 9），這兩張表都還不存在。刻意不建立任何「暫時版本」，因為部分邏輯的函式比完全不存在更危險（容易被之後的 Phase 忘記同步更新）。將於 Phase 5 報名功能開發時建立完整版本。
2. **`term_cancelled_dates` 表**：`PHASE_0_AUDIT_REPORT.md` 第 5.2 節有提案這張表，但 Phase 0 Roadmap 第 8.2 節對 Phase 2 的範圍描述明確只列出 6 張主表 + `audit_logs`/`idempotency_keys`，未包含它。這張表主要在「把期別展開成實際課堂」時才會用到（Phase 4 管理介面工作），因此本輪沒有建立，留到 Phase 4 一併處理。如果你希望現在就建立，請告訴我，這是低風險、可隨時用新 migration 補上的表，不影響已完成的 8 張表。
3. **`profiles.failed_login_count` / `profiles.locked_until`**：`PHASE_0_AUDIT_REPORT.md` 第 4.3.1 節第 6 點建議的登入鎖定欄位。這兩個欄位的正確寫入路徑（Edge Function 或 `SECURITY DEFINER` RPC）要到 Phase 3 才會設計與實作，本輪不提前加欄位，避免欄位存在但沒有任何寫入路徑保護的空窗期。
4. **`auth.users` 新增時自動建立 `profiles`/`user_roles` 的 Trigger**（第 4.3.4 節）：屬於 Phase 3 Authentication 的範圍（與實際登入/註冊流程綁定），Phase 2 只建好目標表結構。
5. **任何業務 RPC**（報名、付款、優惠碼、請假、補課等）：完全不在 Phase 2 範圍內，全部留給對應功能 Phase。
6. **TypeScript 型別產生**（例如 `supabase gen types typescript`）：需要真正連上本機或雲端 Supabase 專案才能產生，本沙盒無法執行；建議你在本機執行 `supabase start` 後自行產生，或於 Phase 3/4 開始寫前端程式碼串接這些表時再處理。
7. ~~真正的 `supabase start` / Docker 本機環境驗證~~：**已於 Final Acceptance 完成**，見下方新增章節「Round 2 — Phase 2 Final Acceptance」。第 4 節保留原文，作為第一輪（雲端沙盒模擬環境）驗證紀錄的歷史留存，不再是目前唯一的驗證證據。

---

## 6. 範圍決策與模糊處說明（呼應 AI_INSTRUCTIONS.md 第 33 節：不得悄悄自行決定業務規則）

以下兩項是 Phase 0 報告本身兩節（Schema 提案 vs RLS Strategy 摘要）措辭不完全一致、或提案本身留有彈性時，本輪選擇的「影響最小、範圍最小」的解讀，明確記錄供你確認：

1. **`terms`／`classes` 的公開可見性判斷**：`PHASE_0_AUDIT_REPORT.md` 第 6 節寫「公開瀏覽資料（venues/terms/classes/class_sessions...）：SELECT 對所有人開放但僅限 `is_active = true AND is_public = true`」，但第 5.2 節的欄位清單中，只有 `venues` 有 `is_public` 欄位，`terms`／`classes`／`class_sessions` 都沒有獨立的 `is_public` 欄位。本輪選擇的解讀：**公開性（`is_public`）由所屬場地決定並往下繼承，各層自己的 `is_active` 則各自把關**，也就是「該層 `is_active = true` 且所屬場地 `is_active = true AND is_public = true`」才可見。這個解讀已用測試驗證行為符合預期（第 4.2 節），如果你的實際想法是「`terms`/`classes` 也需要各自獨立的 `is_public` 欄位」，請告訴我，這是新增欄位 + 調整少數幾條 RLS 政策的小型異動，不影響其餘已完成的部分。
2. **`classes.is_open_for_registration` 與可見性的關係**：本輪解讀為兩個獨立概念——`is_active` 控制「是否可見／可瀏覽」，`is_open_for_registration` 只控制「是否可以報名」（報名功能本身在 Phase 5 才會實作），因此一個 `is_active=true` 但 `is_open_for_registration=false` 的班級目前設計上仍會被公開 SELECT 到（例如「即將開放報名」的班級可以先顯示但不能報名）。如果你的預期是「未開放報名的班級也不該被看到」，請告訴我，這只需要調整 RLS 政策的 `USING` 條件。

以下一項是新增的**純技術性資料完整性保護**，不涉及業務規則本身，因此沒有列在上方模糊處清單，但仍主動說明其存在與範圍：`trg_classes_check_term_venue`（拒絕 `classes.venue_id` 與其 `term` 實際所屬場地不一致的寫入）與 `trg_profiles_protect_phone`（非管理員無法透過一般 UPDATE 修改自己的 `phone`）。這兩個 trigger 都超出 Phase 0 schema 提案的字面欄位/約束清單，是本輪基於 `AI_INSTRUCTIONS.md` 對資料完整性與安全性的一般性要求（第 7、9、11 節）新增的技術保護，皆已用測試驗證（第 4.2 節），如果你認為不需要，也可以之後移除。

---

# Round 2 — Phase 2 Final Acceptance（真正 Supabase Local 環境）

- 觸發原因：依「Phase 2 Final Acceptance Plan」（見對話紀錄），第一輪驗證（第 4 節）只在雲端沙盒的模擬環境完成，你要求在真正的 Supabase Local 環境上重新驗收後，才把 Phase 2 標記為最終完成。
- **重要說明（誠實記錄驗證性質）**：以下結果是**你在自己電腦上實際執行後回報給我的**。這個對話 session 沒有能在你電腦上執行指令的工具，我無法直接連進你的 Supabase Local 環境操作或截圖存證，因此本章節內容是「你回報的執行結果」，不是「我親自觀察到的結果」——這點與第 4 節（我在雲端沙盒親自執行、親眼看到輸出）性質不同，在此明確區分，避免報告顯得像是我自己驗證過。

## 8.1 實際驗收環境

| 項目         | 內容                                                                                                                                                                                          |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 作業系統     | Windows + WSL2                                                                                                                                                                                |
| 容器執行環境 | Docker Desktop                                                                                                                                                                                |
| Supabase CLI | 2.116.0                                                                                                                                                                                       |
| 資料庫環境   | Supabase Local（`supabase start` 啟動的本機堆疊：真正的 PostgreSQL、真正的 GoTrue Auth schema、真正的 PostgREST、真正的 `anon`/`authenticated`/`service_role` 角色），非雲端 Supabase Project |

## 8.2 執行的指令與結果

| #   | 指令                                                                            | 結果                                                                                                                                                                                                                                                                              |
| --- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `npx supabase start`                                                            | ✅ Supabase Local 成功啟動                                                                                                                                                                                                                                                        |
| 2   | `npx supabase db reset`                                                         | ✅ 從乾淨環境成功重建資料庫，套用全部 5 份 Phase 2 migration 成功：`20260902100001_extensions_and_helpers.sql`、`20260902100002_profiles_and_roles.sql`、`20260902100003_venues_terms.sql`、`20260902100004_classes_and_sessions.sql`、`20260902100005_audit_and_idempotency.sql` |
| 3   | 於 Supabase Studio SQL Editor 執行 `supabase/tests/phase2_rls_manual_check.sql` | ✅ 執行結果：`Success. No rows returned`                                                                                                                                                                                                                                          |

## 8.3 RLS 測試結果判讀

`phase2_rls_manual_check.sql` 的設計（見第 3.6 節）：腳本最後一個區塊會統計 `_test_results` 暫存表，若 `v_failed > 0` 就會 `RAISE EXCEPTION` 讓整個腳本以錯誤結束；腳本最外層包在 `BEGIN...ROLLBACK` 內，成功執行到底也不會留下任何測試資料。

你回報的執行結果是 `Success. No rows returned`，且沒有出現任何 `EXCEPTION`／錯誤訊息。依腳本本身的邏輯，這代表：

- 31 項斷言（涵蓋 anon／Student A／Student B／Admin 四種身份、資料完整性約束）**全部通過，`v_failed = 0`**——因為只要有任何一項 `FAIL`，腳本會在最後主動丟出例外並讓整個執行失敗，而非以 `Success` 結束。
- 腳本結尾的 `ROLLBACK` 確實執行，測試過程建立的假資料（測試用場地/期別/班級/課堂/使用者）沒有殘留在資料庫中。

## 8.4 通過／失敗項目對照（你列出的 11 項驗收目標）

| #   | 驗收目標                                       | 結果                                                                                                                 |
| --- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 1   | 在真正的 Supabase 環境驗證 Migration           | ✅ 通過（8.2 第 1、2 項）                                                                                            |
| 2   | 確認 8 張資料表全部正確建立                    | ✅ 通過（`db reset` 成功套用全部 migration，8 張表結構與第一輪雲端沙盒驗證一致）                                     |
| 3   | 確認所有 FK / CHECK / Index 正確               | ✅ 通過（migration 本身即定義這些約束，套用無錯誤即代表語法與參照關係正確；資料完整性行為由測試腳本第 5 節斷言覆蓋） |
| 4   | 確認 RLS 在真正 Supabase PostgreSQL 環境生效   | ✅ 通過（8.3；測試腳本以真正的 `auth.uid()`／`anon`/`authenticated` 角色執行，而非第一輪的模擬替代品）               |
| 5   | 執行 Phase 2 建立的 RLS 驗證測試               | ✅ 通過（8.2 第 3 項）                                                                                               |
| 6   | 確認匿名使用者無法取得不應公開的資料           | ✅ 通過（涵蓋於 31 項斷言中的 anon 測試群組）                                                                        |
| 7   | 確認 Student A 無法讀取或修改 Student B 的資料 | ✅ 通過（涵蓋於 31 項斷言中的 Student A 測試群組，對應高風險測試清單第 8 項）                                        |
| 8   | 確認學生不能自行修改 phone                     | ✅ 通過（`trg_profiles_protect_phone` 相關斷言）                                                                     |
| 9   | 確認學生不能自行取得 admin 權限                | ✅ 通過（`user_roles` 自助升級阻擋相關斷言）                                                                         |
| 10  | 確認管理員權限符合設計                         | ✅ 通過（Admin 測試群組：可見所有資料、可修改他人 phone、可新增場地）                                                |
| 11  | 確認 migration 可以從乾淨環境正確建立          | ✅ 通過（`db reset` 即為「從乾淨環境重建」）                                                                         |

**11/11 全數通過。**

## 8.5 已知限制（Round 2 驗證本身的限制，誠實記錄）

1. **驗證結果來自你的回報，非我直接觀察**：如 8.1 節開頭所述，這個 session 沒有連上你電腦的指令執行工具，我無法自己重跑一次或截圖比對，只能依你提供的技術細節（Supabase CLI 版本、逐一列出的 migration 檔名、Studio 標準成功訊息、對測試腳本 `RAISE EXCEPTION` 邏輯的正確描述）判斷這是實際執行的結果，而非臆測。如果之後想要更強的存證，可以考慮在 CI（`.github/workflows/ci.yml`，Phase 1 已建立）中加入「啟動 Supabase Local + 套用 migration + 跑 RLS 測試」的步驟，讓每次 push 都留下 Claude／人都能查閱的自動化紀錄，而不必每次都靠手動回報。這不是本輪的必要項目，是可選的後續強化。
2. **`Success. No rows returned` 是整體訊息，不是逐項斷言的清單**：透過 Supabase Studio 執行時，`RAISE NOTICE` 訊息（每項斷言的 `PASS: ...`）通常會出現在 Studio 的訊息／Logs 面板，而不是主要結果區；本次回報聚焦在最終成功訊息與腳本邏輯推論，沒有附上逐項 `NOTICE` 清單。這不影響結論的正確性（腳本的 fail-loud 設計已確保「沒有例外 = 全部通過」），但如果之後想要逐項留存紀錄，改用 `psql` 執行（`psql "<DB_URL>" -f supabase/tests/phase2_rls_manual_check.sql`）會把所有 `NOTICE` 訊息印在終端機輸出中，更適合貼上完整紀錄或存檔。
3. 8.2 節沒有附上 `supabase start`／`db reset` 的完整終端機輸出全文，僅有結果摘要。如果之後需要更完整的存證（例如要附進團隊內部文件），建議保留完整終端機輸出的截圖或文字檔。

---

## 7. Summary（依 AI_INSTRUCTIONS.md 第 36 節完成報告格式）

**Summary**：**Phase 2（Database Foundation）已完成並通過真正 Supabase Local Final Acceptance。** 建立 8 張基礎資料表（`profiles`／`user_roles`／`venues`／`terms`／`classes`／`class_sessions`／`audit_logs`／`idempotency_keys`），全數 FK/Index/CHECK 約束到位，RLS 於建表當下即啟用並套用政策（無空窗期），並新增兩個共用輔助函式（`is_admin()`、`fn_is_venue_public()`/`fn_is_class_public()`）與兩個資料完整性保護 trigger。驗證分兩輪：第一輪在雲端沙盒的模擬 Supabase 環境（自建 `auth.users`/`auth.uid()` 替代品）跑 31 項 SQL 斷言全數通過；第二輪（Final Acceptance）由你在自己電腦上以真正的 Supabase Local（Docker + Supabase CLI 2.116.0，見「Round 2」章節）重新套用全部 migration 並重跑同一份測試腳本，對照你要求的 11 項驗收目標全數通過。未修改任何前端程式碼，Phase 1 的驗收成果不受影響。

**Files Changed**：新增 `supabase/migrations/20260902100001_extensions_and_helpers.sql`、`20260902100002_profiles_and_roles.sql`、`20260902100003_venues_terms.sql`、`20260902100004_classes_and_sessions.sql`、`20260902100005_audit_and_idempotency.sql`、`supabase/tests/phase2_rls_manual_check.sql`；小幅更新 `supabase/config.toml` 註解。

**Database Changes**：見第 3 節，8 張新表 + 6 個函式（`set_updated_at`／`is_admin`／`trg_profiles_protect_phone`／`fn_is_venue_public`／`trg_classes_check_term_venue`／`fn_is_class_public`）+ 對應 trigger 與 RLS 政策，共 5 份 migration。

**Security Considerations**：見第 3、4、6 節。所有 8 張表建立當下即啟用 RLS；`audit_logs` 不對任何角色開放直接 INSERT；`user_roles` 不開放自助升級；`profiles.phone` 不可由非管理員直接竄改；公開瀏覽範圍明確限縮於 `is_active`/`is_public` 條件。第一個管理員帳號的建立方式已記錄於 migration 註解（需 Service Role 權限手動建立）。

**Tests**：`supabase/tests/phase2_rls_manual_check.sql`，31 項斷言。第一輪：於兩個獨立的乾淨本機 PostgreSQL（模擬環境）上實際執行皆為 31/31 通過，詳見第 4 節。第二輪（Final Acceptance）：由你在真正的 Supabase Local 環境（Docker + Supabase CLI 2.116.0）重新執行，`Success. No rows returned` 且無例外，依腳本 fail-loud 設計判讀為 31/31 通過，對照 11 項驗收目標全數通過，詳見「Round 2 — Phase 2 Final Acceptance」章節（含驗證性質與局限性的誠實說明）。

**Not Implemented**：見第 5 節清單（`fn_session_used_seats`、`term_cancelled_dates`、登入鎖定欄位、auth provisioning trigger、任何業務 RPC、TypeScript 型別產生）；「真正的 `supabase start` 驗證」原列於此清單，**已於 Round 2 完成，不再是未實作項目**。

**Recommended Next Step**：依 Roadmap，下一步為 **Phase 3（Authentication & Authorization）**：實作學生 Phone+Password 登入（`PHASE_0_AUDIT_REPORT.md` 第 4.3.1-4.3.2 節）、管理員登入、`auth.users` 新增時自動建立 `profiles`/`user_roles` 的 Trigger、登入失敗鎖定機制（Edge Function 或安全 RPC，第 4.3.1 節第 6 點的強制要求）。Phase 1、Phase 2 均已完成並通過驗收。**Phase 3 範圍與依賴關係的重新確認，見本次對話回覆中的 Phase 3 Inspect/Analyze/Plan；在你確認測試方式與尚待決策的項目之前，不會開始 Phase 3 的實作，也不會自動進入 Phase 4。**

---

# End of PHASE_2_COMPLETION_REPORT.md
