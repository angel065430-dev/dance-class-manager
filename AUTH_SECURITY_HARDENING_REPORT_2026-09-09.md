# Auth 安全修正報告（2026-09-09）

## 結論

本次修正保留 Vue 3、TypeScript、Supabase、既有 UI 架構、課程資料與所有既有 migration；只新增 append-only migration 與必要程式／測試。未執行 `db reset`、未連線或修改正式資料、未部署正式環境。

## 修正內容

### 1. 公開建立帳號改為管理員核准邀請

- 新增管理員專用 `admin-create-student-invitation` Edge Function。
- 管理員需先登入、通過 Supabase `getUser()`，並由資料庫 `user_roles` 再確認真正 `admin` 角色。
- 邀請碼綁定正規化手機號碼，有效 72 小時、單次使用；建立新邀請會撤銷同手機未使用舊邀請。
- 資料庫只保存手機與邀請碼的 SHA-256 指紋，不保存邀請碼原文。
- 公開 `create-student-account` 必須原子 claim 正確邀請，建立成功後才 finalize；失敗則釋放 claim 或刪除未完整建立的 Auth user。
- Supabase 公開 signup 設為關閉；帳號只能由受控 Edge Function 以 service role provisioning。

### 2. 登入與註冊 throttle 原子化

- `consume_student_signup_attempt` 與 `reserve_student_login_attempt` 使用 PostgreSQL `SELECT ... FOR UPDATE`，並發請求不再先讀後寫或遺失計數。
- 登入在驗證密碼前先保留一次失敗額度；第 5 次失敗後鎖定 15 分鐘。
- 登入成功後必須成功執行 `clear_student_login_failures` 才回傳 token；清除失敗會撤銷 session 並回傳 503（fail closed）。
- throttle RPC 查詢／寫入／回傳形狀異常時，一律拒絕請求，不再繼續驗證或建立帳號。

### 3. 學生登入路徑統一

- 註冊成功後仍呼叫 `loginStudent()`，只經 `student-pin-login` Edge Function。
- 學生路徑沒有直接呼叫 `supabase.auth.signInWithPassword`；該呼叫只保留在管理員 Email/Password 登入與伺服器端受控學生登入。

### 4. 管理員重設 PIN

- Auth JWT 驗證後再查詢 `user_roles(role='admin')`；角色查詢錯誤時回 503，不能降級放行。
- 重設原因改為必填。
- 密碼變更前必須先成功寫入 `student_pin_reset_started`；寫入失敗則 PIN 不變。
- Auth 更新失敗會寫入 `student_pin_reset_failed`；成功後必須寫入 `student_pin_reset_completed` 才回傳一次性 PIN。
- audit log 不包含 PIN；完成稽核失敗時不回傳 PIN，明確要求管理員再次重設。

### 5. 秘密與敏感資訊

- 前端只讀 `VITE_SUPABASE_URL` 與 `VITE_SUPABASE_ANON_KEY`。
- `SUPABASE_SERVICE_ROLE_KEY` 只出現在 Edge Function server runtime 與隔離本機並發測試環境變數，不進入 Vite bundle。
- PIN 只作為 Supabase Auth password 傳送；不寫入 `profiles`、自訂資料表、audit log 或 console log。
- 公開登入錯誤維持通用訊息，不回傳帳號是否存在；邀請失效也使用單一通用訊息。
- 所有新資料表與 RPC 都撤銷 `PUBLIC`、`anon`、`authenticated` 權限，只授權 `service_role`。

## 新增／修改檔案

### 新增

- `supabase/migrations/20260909010017_harden_student_auth.sql`
- `supabase/functions/admin-create-student-invitation/index.ts`
- `tests/unit/authSecurity.spec.ts`
- `tests/concurrency/studentAuthThrottle.spec.ts`
- `supabase/tests/student_auth_concurrency_check.sql`
- `.env.example`
- `AUTH_SECURITY_HARDENING_REPORT_2026-09-09.md`

### 修改

- `supabase/functions/_shared/security.ts`
- `supabase/functions/create-student-account/index.ts`
- `supabase/functions/student-pin-login/index.ts`
- `supabase/functions/admin-reset-student-pin/index.ts`
- `supabase/config.toml`
- `src/composables/useAuth.ts`
- `src/services/studentAccounts.ts`
- `src/pages/student/RegisterView.vue`
- `src/pages/admin/AdminStudentsView.vue`
- `tests/unit/adminStudents.spec.ts`
- `e2e/registration-mvp.spec.ts`

## 驗證結果

- TypeScript (`vue-tsc --noEmit`)：通過。
- ESLint：通過。
- Vitest：26 passed；2 個隔離本機 Supabase 並發測試因本執行環境沒有 Docker/PostgreSQL 而依條件 skip。
- Production build (`vite build`)：通過。
- Playwright smoke：本執行環境未安裝 Chromium，無法啟動；不是應用斷言失敗。
- SQL migration／真實並發 RPC／完整邀請 E2E：需在 Angel 的 Windows 本機 Supabase 執行後確認。

## Windows 本機驗收（只限 local Supabase）

1. 先確認目前目錄是專案，並執行 `npx supabase status`，URL 必須為 `127.0.0.1`。
2. 使用 `npx supabase migration up --local` 套用新增 migration；不要執行 `db reset`。
3. 從 `npx supabase status -o env` 取得 local anon/service role key，放入未提交的 `.env.e2e.local` 或目前 PowerShell session。
4. 執行 TypeScript、ESLint、Vitest；設定 `LOCAL_SUPABASE_URL` 與 `LOCAL_SUPABASE_SERVICE_ROLE_KEY` 後，2 個並發測試不得再 skip。
5. 設定隔離本機 E2E admin 後執行 Playwright；預期完整流程與未授權邀請拒絕皆通過。

## 正式部署順序（尚未執行）

1. 匯出／驗證 Supabase 正式資料庫備份，並記錄目前 migration 與三支 Auth Function 版本。
2. 在 staging 或 local 完整跑 migration、並發測試、邀請 E2E。
3. 正式資料庫只執行 `20260909010017_harden_student_auth.sql`；禁止 reset。
4. 先部署 `student-pin-login`、`admin-reset-student-pin`、`admin-create-student-invitation`。
5. 驗證管理員 JWT、admin role、邀請建立、錯誤時 fail closed 與 audit log。
6. 將 Supabase Auth 公開 Email signup 關閉。
7. 在短暫註冊維護窗口部署新版 `create-student-account`，隨即部署新版 Vue 前端。
8. 用專用測試學生走一次「管理員邀請 → 註冊 → 安全登入 → 登出 → 再登入」，再檢查 throttle、invitation status 與 audit log。
9. 驗收完成前不開放學生使用。

## 回滾方案

- 本 migration 為新增式，不更動課程／訂單／正式學生資料；緊急時保留新表與函式，不必 DROP，也不做資料庫 restore。
- 安全回滾優先「停止新帳號建立」：保持公開 signup 關閉，暫停或回傳維護訊息，不回退到只憑手機即可建立帳號的舊 Function。
- 登入若需回滾，部署已封存的前一版 `student-pin-login` 只能作短期緊急措施，且應同時限制入口；建議以 forward-fix 為主，避免重新引入非原子 throttle。
- 前端可回滾至前一版，但新帳號建立仍必須保持關閉，直到安全 Function／UI 版本一致。
- 若 migration 本身有問題，新增一支後續 corrective migration 修正或 revoke 新 RPC；不得修改已套用 migration、不得 `db reset`、不得刪除正式資料。

## 待 Angel 確認

- 正式部署前，先提供 Windows local 的 migration、2 個並發測試與完整 Playwright E2E 結果。
- 收到確認前不部署任何正式環境。
