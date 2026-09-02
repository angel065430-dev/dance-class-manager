# PHASE_0_AUDIT_REPORT.md

# 舞蹈課程報名／請假／補課管理系統
## Phase 0 — Project Audit & Implementation Planning 報告

- 報告日期：2026-09-02
- 依據文件：`MASTER_SPEC.md`（v.目前版本，47 節）、`AI_INSTRUCTIONS.md`（37 節）
- 專案資料夾：`dance-class-manager`（使用者電腦，OneDrive 同步）
- 本報告角色：僅完成 Phase 0（專案稽核與規劃）。**尚未撰寫任何正式程式碼、尚未建立任何資料庫 migration、尚未進入 Phase 1。**
- **本文件歷經三輪修訂**：Round 1（初版稽核）→ Round 2（依使用者最終決策全面更新，2026-09-02）→ **Round 3（本次，小型技術補充，2026-09-02）**。Round 3 範圍限定在三項技術注意事項的補充（詳見第 4.3.2 節登入鎖定安全流程、第 5.3 節補課名額雙重限制、第 11.3 節跨場地拆單部分成功處理），**未推翻 Round 2 已確認的任何架構或決策**，Phase 0 → Phase 1 Gate 維持已通過狀態。歷史內容皆保留於下方各節，以「編輯既有內容」方式呈現，方便對照。

---

# Revision Summary（第二輪修訂摘要）

## 本輪修訂重點

1. **Authentication 決策全面翻案**：重新查證 Supabase 官方文件後，確認 Supabase Auth **原生支援 Phone + Password**（`signUp({phone, password})` / `signInWithPassword({phone, password})`），第一輪報告「Supabase 不支援手機+PIN」的前提有誤，已撤回原本的 A（合成 Email）／B（OTP）／C（自訂 JWT）三方案，改為以官方原生 Phone + Password 為唯一實作路徑，並重新分析註冊流程、電話格式標準化、首次驗證、忘記 PIN、號碼回收風險、Rate Limiting、CAPTCHA、與 `profiles` 表關聯（詳見第 4.3.1 節全新版本）。
2. **PIN 規則確認**：6 位數字、封鎖過度簡單組合、由 Supabase Auth 密碼機制處理、不明碼存放、忘記 PIN 第一版採管理員協助重設，並補上防暴力破解的具體設計（Rate Limiting + CAPTCHA + 應用層鎖定）。
3. **請假取消規則已確認為正式商業規則**（不再是待決策項目）：若請假釋出的名額已被其他補課學生使用，**禁止學生取消請假**。此規則已同步寫回 `MASTER_SPEC.md`（見本節下方「同步變更的文件」）。
4. **補課核准模式確認**：全系統預設「自動核准」，但保留管理員手動核准／駁回／手動建立／手動調整名額的完整能力，第一版不做場地/班級/課堂各自獨立設定核准模式。
5. **Cron 策略確認**：優先使用 Supabase Cron / `pg_cron`，待 Supabase 專案建立後於 Phase 2 或 Phase 9 實際驗證即可，**不阻擋 Phase 1**。
6. **運動中心補課基礎名額**：確認為「班級層級設定 `default_base_makeup_capacity`，建立 Class Session 時帶入預設值，管理員可對單一 Session 覆蓋調整」——與第一輪報告的原始提案一致，本輪僅正式確認。
7. **席位轉讓規則確認**：系統不處理學生間金流、已付款原則上不退款，系統只負責記錄轉讓資格、原學生、受讓學生、轉讓時間、管理員處理紀錄與完整歷史稽核。
8. **管理員 MFA 分階段確認**：Phase 3 先完成一般 Admin Auth（Email+Password），MFA/TOTP 強制要求排入 Phase 12（Production Security Hardening）。
9. **CSV 匯出優先順序調整**：不再視為 Nice-to-have，確認為上線前必須完成項目；Calendar（Google Calendar／ICS）可排在核心報名/請假/補課功能之後，不阻擋核心開發。
10. **Testing 策略確認**：採用 Vitest + Supabase CLI + Playwright，並新增 9 項高風險測試案例的正式清單（詳見第 8 節更新版）。
11. **Phase 排序調整由「建議」改為「已確認」**：`audit_logs`、`idempotency_keys` 提前至 Phase 2，最小測試框架提前至 Phase 1。
12. **新增資料庫設計深入分析**（第 11 節，全新章節）：
    * A. 整期報名如何與單堂報名、補課共同影響同一堂課的正課容量計算，統一公式與單一計算來源。
    * B. 學生一次整期報多班時，確認採用 **Atomic Transaction（全部成功或全部失敗）**。
    * C. 訂單跨場地問題，確認 **依場地自動拆單**，一張 `orders` 只屬於一個 `venue_id`。

## 已解除的問題（共 9 項，原編號對照見第 9 節）

原 Q1（登入方案選擇）、Q3（請假取消規則）、Q4（補課核准模式）、Q5（pg_cron 可用性是否阻擋）、Q6（運動中心基礎名額層級）、Q7（席位轉讓金流規則）、Q8（Admin MFA 時機）、Q9（CSV/Calendar 優先順序）、Q10（測試工具選擇）、Q11（Phase 排序）——**共 10 項原本列為待決策的問題，本輪已全部確認**（Q2 PIN 規則也已確認，但衍生出新的技術實作待辦，非商業決策問題，故不計入「待決策」清單）。

## 仍待留意但不阻擋 Phase 1 的項目

* 首次手機簡訊驗證是否啟用（成本 vs 安全的取捨，詳見第 4.3.1 節）。
* 席位轉讓是否需要管理員逐筆核准，或學生可直接自助轉讓後由系統記錄（MASTER_SPEC.md 第 26 節未明確定義流程型態）。

詳見第 9 節「更新後的待決策問題」與第 10 節「是否可以進入 Phase 1」的完整結論。

## 同步變更的文件

依 `AI_INSTRUCTIONS.md` 第 46 節「需求變更規則」（先修改 MASTER_SPEC.md，再記錄新規則），本輪已將**請假取消規則**這項新確認的正式商業規則，同步寫回使用者資料夾中的 `MASTER_SPEC.md.txt`（於原第 15.3 節下方新增明確條文），並在檔案末尾新增「Phase 0 Confirmed Decisions Addendum」章節，完整記錄本輪所有已確認的商業規則，方便未來查閱時作為單一事實來源，不需要回頭翻閱聊天紀錄。

---

# 1. Current Project Status（現況檢查）

## 1.1 目錄檢查結果

檢查已連接資料夾 `dance-class-manager` 內容（遞迴列出），結果如下：

```text
dance-class-manager/
├── AI_INSTRUCTIONS.md.txt   (14,092 bytes)
└── MASTER_SPEC.md.txt        (24,267 bytes)
```

**沒有找到**以下任何項目（明確聲明，不假設存在）：

* `package.json` — 不存在
* `vite.config.ts` / `vite.config.js` — 不存在
* `src/` 目錄 — 不存在
* 任何 Vue 3 專案結構 — 不存在
* `.env` / `.env.example` — 不存在
* `supabase/` 目錄、`supabase/config.toml`、`supabase/migrations/` — 不存在
* 任何 Git 版本控制紀錄（`.git/`）— 不存在
* 任何測試設定（Vitest / Playwright / pgTAP 等）— 不存在
* 任何既有 UI 元件、Composable、Service、Store 檔案 — 不存在
* `vercel.json` 或其他部署設定 — 不存在

已向使用者確認（透過澄清問題）：**這是一個完全全新（greenfield）的專案**，MASTER_SPEC.md 標題所寫的「Current Architecture: Vue 3 + TypeScript + Vite + Tailwind CSS + Supabase + Vercel」是**目標架構**，不是目前已存在的實作。這點很重要，因為 `AI_INSTRUCTIONS.md` 第 2 節要求「不得根據舊程式碼恢復已淘汰需求」——但目前沒有任何舊程式碼可供參考，因此本報告的 Gap Analysis 是「規格 vs 空白專案」，而不是「規格 vs 現有系統」。

## 1.2 其他檢查項目

| 檢查項目 | 結果 |
|---|---|
| 現有前端技術 | 不存在（尚未選定實作，僅有規格指定 Vue3+TS+Vite+Tailwind） |
| 現有 Vue 架構 | 不存在 |
| 現有 Supabase 整合 | 不存在（無 client 初始化程式碼、無 `.env`） |
| 資料庫 migrations | 不存在 |
| 現有 Authentication | 不存在 |
| 現有 Components | 不存在 |
| 現有 Pages | 不存在 |
| 環境變數設定方式 | 不存在，需從 Phase 1 開始建立 `.env` / Vercel 環境變數 |
| 測試工具 | 不存在，需從 Phase 1 決定測試策略（見第 8 節） |
| claude.ai Project「My Zumba class」文件 | 目前 0 份文件，尚未儲存任何規格或決策紀錄 |

## 1.3 結論

Phase 0 不需要處理任何「既有程式碼相容性」問題，可以直接依 MASTER_SPEC.md 從零規劃架構。但也代表 Phase 1 起的每一步都需要完整建置（專案骨架、CI、環境變數、資料庫），沒有可以沿用的基礎。

---

# 2. 規格重點整理

## 2.1 已確定的核心功能（MASTER_SPEC.md 明確定義）

* 三種角色：Student、External Center Student、Admin（第 3 節）
* 學生登入：手機號碼為主要識別，須與 Supabase Auth 相容（第 4.1 節）
* 管理員登入：正式身份驗證 + Role + RLS（第 4.2 節）
* 場地管理：支援自營教室／運動中心兩種營運模式（第 5 節）
* 期別、常態班級、課堂（Class Session）三層結構（第 6-7 節）
* 整期報名（可跨多班級同一訂單）、過半停止整期報名規則（第 8 節）
* 單堂報名，與整期報名資格分開管理（第 9 節）
* 特別活動／假日快閃課，支援多堂同時報名與套裝優惠（第 10 節）
* 優惠碼系統，後端驗證與計算折扣（第 11 節）
* 收款：銀行轉帳／LINE 轉帳／現金，不依賴 QR Code（第 12 節）
* 運動中心學生資格登記制度（External Student Membership）（第 14 節）
* 請假：90 分鐘前截止、管理員例外、取消請假需重新驗證名額（第 15 節）
* 補課資格：±20 天有效期、場地隔離、同班級規則依報名類型不同（第 16-18 節）
* 補課預約：自動篩選資格、開課前 1 小時確認截止（第 19-20 節）
* 名額必須由資料庫最終判斷，禁止前端讀取-減一-寫入的不安全流程（第 21 節）
* 運動中心補課名額公式：基礎名額 + 當日請假數 + 人工調整 − 已預約數，且各組成部分需可稽核（第 22 節）
* 每堂課獨立門禁密碼與公布狀態（第 24 節）
* 點名功能，與報名/補課建立明確關聯（第 25 節）
* 席位轉讓，需保留歷史（第 26 節）
* 管理後台儀表板、報名管理、學生管理、CSV 匯出、行事曆整合、品牌設定、FAQ（第 27-33 節）
* Realtime（Supabase Realtime 僅負責 UI 更新，正確性仍由後端保證）（第 34 節）
* Database 為唯一正式資料來源，禁止 LocalStorage 作為業務資料（第 35 節）
* Security：Supabase Auth + RLS，稽核紀錄、Idempotency、XSS 防護、時區統一（第 36-40 節）
* 部署目標：Vercel（前端）+ Supabase（資料庫/驗證）（第 41-42 節）
* 43 節列出的 24 個核心資料實體（詳見第 5 節 Schema Proposal）

## 2.2 尚未開始實作的功能

**全部**。目前沒有任何程式碼，因此 MASTER_SPEC.md 中列出的所有功能（第 5-33 節）都屬於「未實作」。詳見第 3 節 Gap Analysis。

## 2.3 技術風險

1. **手機 + PIN 登入的實作細節**（第一輪報告曾誤判 Supabase 不支援手機+密碼，已於本輪修訂更正）：查證 Supabase 官方文件後確認，Supabase Auth **原生支援** `signUp({ phone, password })` 與 `signInWithPassword({ phone, password })`，因此手機號碼+PIN 可以直接對應到 Supabase 原生的 Phone + Password 機制，不需要合成 Email 或自訂 JWT。剩餘風險改為工程細節層面：PIN 空間刻意設計得很小（僅 6 位數字），必須額外疊加 Rate Limiting、CAPTCHA、應用層登入失敗鎖定，且 Supabase 官方文件本身也提醒「電信商可能回收手機號碼」的帳號接管風險，需要有對應的緩解設計（詳見第 4.3.1 節全新版本）。
2. **時區處理**：課程時間、請假截止時間（90 分鐘）、補課確認截止時間（1 小時）、門禁公布時間都需要以 Asia/Taipei 為準。若儲存欄位型別選擇不當（例如用不含時區的 `timestamp` 或用字串日期），會導致伺服器與瀏覽器解讀不一致。
3. **統一報名結構的複雜度**：整期報名、單堂報名、特別活動報名的資料需要共用 `orders` / `order_items` / `registrations` 結構，但三者的資格驗證規則、名額計算規則、可補課規則都不同，Schema 與 RPC 設計需要謹慎，避免用單一大而全的表格造成後續難以維護。
4. **RLS 政策覆蓋面大**：約 24 張表格中，多數需要「本人或管理員可讀寫」的政策，容易在某張表遺漏 RLS 而造成資料外洩，需要有系統性的測試（見第 12 節）。
5. **pg_cron / 排程任務**（已確認策略，不阻擋 Phase 1）：補課「未確認視為已使用」與名額回收，理想上需要排程任務定期清理逾期未確認的補課預約。已確認優先採用 Supabase Cron / `pg_cron`，待 Supabase 專案於 Phase 1-2 實際建立後，在 Phase 9（Makeup System）實作前驗證該功能是否可用；若實際環境無法使用，再改用 Vercel Cron Job 呼叫受保護的 Edge Function 作為替代方案。此項不再阻擋任何前面的 Phase。
6. **金額精度**：所有金額欄位必須使用 `numeric`，不可使用浮點數（`float`/`double`），否則優惠碼折扣計算可能出現誤差。

## 2.4 資料庫風險

1. **不可硬刪除交易資料**：場地停用、班級停開、學生資料異動時，第 5 節與 `AI_INSTRUCTIONS.md` 第 24 節都要求歷史資料不得遺失，因此絕大多數主表需要 `is_active` / 狀態欄位而非直接 `DELETE`，外鍵也應避免 `ON DELETE CASCADE`（改用 `RESTRICT` 或 `SET NULL` + 保留歷史快照）。
2. **唯一性約束需搭配「有效狀態」**：例如「同一學生不可重複報名同一堂單堂課」這條規則，若簡單用 `UNIQUE(student_id, class_session_id)`，會導致「取消後想重新報名」失敗。需要用 Partial Unique Index（`WHERE status = 'active'`）。
3. **補課名額公式的組成欄位需獨立保存**：第 22.2 節明確要求不可只存最終剩餘名額，需要拆成基礎名額、當日請假數（可即時計算，不必存）、人工調整（需要獨立表以保留每次調整的原因/操作者/時間）、已預約數（可即時計算）。
4. **多重報名型態共用表格 vs 分表**：需要在 Schema Proposal 中明確選擇「一張 `registrations` 表用 `registration_type` 區分」還是「分成三張表」，兩者對 RLS、查詢效能、未來擴充都有影響（詳見第 5 節的設計說明與取捨）。

## 2.5 Realtime 需求

* 課堂名額（`class_sessions` 相關的報名數/補課預約數）即時更新 — 影響：前台瀏覽頁、我的報名頁、管理後台儀表板。
* 請假狀態變化 — 影響：學生本人的請假列表、管理員待審核列表。
* 補課預約狀態變化（含核准/駁回/確認）— 影響：學生本人、管理員審核佇列。
* 課程開放/關閉報名狀態變化。
* 公告（announcements）/品牌設定變更。
* 門禁密碼公布事件（僅推播給具資格的學生）。

原則（依 `AI_INSTRUCTIONS.md` 第 25 節）：Realtime 只用來讓 UI 即時反映變化，**任何寫入動作在送出前都必須重新對資料庫驗證**，不可信任 Realtime 推播的資料直接做出「還有名額」的寫入決策。

## 2.6 Authentication 需求

* 學生：手機號碼為主要識別，重新整理頁面後登入狀態需維持（Supabase Auth session/refresh token 天生具備此能力，與登入方式無關）。
* 管理員：正式帳號密碼（或 Magic Link），不可用前端硬編碼或隱藏按鈕充當安全機制。
* 角色必須由後端（Supabase Auth + Role 資料表 + RLS）共同判斷，前端路由守衛僅為 UX，不是安全邊界。

## 2.7 Security / RLS 需求

* 學生只能存取自己的 Profile / Registrations / Orders / Payments / Leave Requests / Makeup Credits / Makeup Reservations。
* 付款狀態變更僅限管理員（透過 RPC / RLS 限制 `UPDATE` 權限，不可讓學生直接 `UPDATE payments`）。
* 優惠碼驗證與折扣計算必須在後端（RPC）進行，前端顯示僅供預覽。
* 門禁密碼僅對「當下具備該堂課出席資格且未請假」的學生可見。
* 稽核紀錄（audit_logs）只能由系統（SECURITY DEFINER 函式/觸發器）寫入，不開放前端直接 `INSERT`。
* Service Role Key 絕對不可出現在前端程式碼或 `VITE_` 開頭的環境變數中。

## 2.8 Race Condition 風險（初步列舉，詳見第 7 節完整分析）

1. 最後一位名額被多人同時搶（一般報名 / 單堂報名 / 特別活動報名）。
2. 補課名額被多人同時搶（尤其運動中心的動態公式）。
3. 優惠碼使用次數上限 / 個人使用上限的併發超用。
4. 請假取消與補課名額已被使用之間的資料矛盾（第 15.3 節明確要求防止；**本輪已確認正式規則：名額已被使用時禁止取消請假**，詳見第 7 節）。
5. 使用者重複點擊 / 網路重試造成重複訂單、重複補課預約、重複扣優惠碼（Idempotency）。
6. 補課「逾時未確認」與「即時查詢可用名額」之間的競態（需要排程清理 + 查詢時即時過濾雙重保險）。

---

# 3. Gap Analysis

## 3.1 已符合

目前專案已符合的需求：**無**（因為尚無任何程式碼實作）。唯一已符合的部分是文件層面：`MASTER_SPEC.md` 與 `AI_INSTRUCTIONS.md` 本身已存在且內容完整、結構清楚，可直接作為 Phase 1 起的開發依據。

## 3.2 部分符合

已存在但需要修改的功能：**無**（無既有功能可供修改）。

## 3.3 未實作

完全不存在的功能——**MASTER_SPEC.md 第 5-33 節列出的所有功能**，包括但不限於：

* 專案骨架（Vue 3 + TS + Vite + Tailwind + Router + Supabase Client）
* 資料庫（全部 24 張表格）與 RLS 政策
* 學生／管理員 Authentication
* 場地／期別／班級／課堂管理
* 整期報名、單堂報名、特別活動報名與訂單流程
* 付款紀錄與管理員付款確認
* 優惠碼系統
* 運動中心學生資格登記
* 請假系統（含 90 分鐘規則、管理員例外、取消請假重新驗證）
* 補課系統（±20 天規則、場地隔離、同班級規則、預約、確認、核准、運動中心公式）
* 特別活動與套裝優惠
* 門禁密碼管理
* 點名
* 席位轉讓
* 管理後台儀表板、報表、CSV 匯出、稽核紀錄檢視
* 品牌設定、FAQ、上課須知
* Realtime 同步
* 行事曆整合（Google Calendar / ICS）
* Idempotency 機制
* 完整測試（單元測試、資料庫測試、e2e）

## 3.4 不應保留

與 MASTER_SPEC.md 衝突的舊架構或舊邏輯：**無**，因為沒有任何舊程式碼、舊 Prompt 或舊 HTML 存在於目前的專案資料夾中。

> 提醒：如果使用者之後在其他地方（例如舊的 HTML Demo、其他 AI 工具產生的程式碼、舊聊天紀錄）找到過去的實作，依照 `AI_INSTRUCTIONS.md` 第 2 節，**不應自動採用**其中的商業規則，必須先比對是否與 MASTER_SPEC.md 一致，衝突時一律以 MASTER_SPEC.md 為準（第 47 節 Source of Truth Priority）。

---

# 4. Proposed Architecture（建議架構）

## 4.1 Frontend Architecture

### Pages（路由）

**公開頁面**
* `/`：首頁（品牌設定、Hero、公告）
* `/courses`：課程瀏覽（依場地/期別篩選）
* `/courses/:classId`：班級詳情與可報名課堂
* `/events`：特別活動列表
* `/events/:eventId`：活動詳情
* `/login`：學生登入
* `/signup`：學生註冊（手機號碼＋PIN 設定）
* `/admin/login`：管理員登入

**學生專區（需登入）**
* `/me`：個人儀表板
* `/me/registrations`：我的報名紀錄
* `/me/orders`、`/me/orders/:orderId`：訂單與付款狀態
* `/me/leave`：請假申請與紀錄
* `/me/makeup`：補課資格與預約
* `/me/makeup/reserve`：補課預約流程
* `/me/door-access`：當日開門資訊
* `/me/external-membership`：運動中心學生資格登記
* `/me/profile`：個人資料維護

**管理後台（需 Admin 角色）**
* `/admin`：儀表板
* `/admin/venues`、`/admin/terms`、`/admin/classes`、`/admin/classes/:id/sessions`
* `/admin/registrations`、`/admin/orders`、`/admin/payments`
* `/admin/coupons`
* `/admin/students`、`/admin/students/:id`
* `/admin/external-memberships`
* `/admin/leaves`
* `/admin/makeups`、`/admin/makeups/approvals`
* `/admin/special-events`
* `/admin/door-access`
* `/admin/attendance`
* `/admin/seat-transfers`
* `/admin/reports`（CSV 匯出）
* `/admin/audit-logs`
* `/admin/brand-settings`

### Components（依領域分組）

* **Layout**：`AppShell`、`StudentShell`、`AdminShell`、`NavBar`、`Announcement Banner`
* **課程瀏覽**：`ClassCard`、`SessionList`、`CapacityBadge`（顯示「僅供參考」的即時名額）
* **報名流程**：`RegistrationCart`、`OrderSummary`、`CouponInput`、`PaymentInstructions`
* **請假/補課**：`LeaveRequestForm`、`LeaveDeadlineCountdown`、`MakeupCreditCard`、`MakeupReservationList`、`MakeupConfirmDialog`
* **管理表格**：通用 `DataTable`（分頁/排序/篩選）、各領域的 Form 元件（`VenueForm`、`TermForm`、`ClassForm`、`SessionForm`、`CouponForm`…）
* **點名/門禁**：`AttendanceGrid`、`DoorAccessPanel`
* **儀表板元件**：`StatCard`、`PendingApprovalsList`、`RealtimeSeatIndicator`、`AuditLogViewer`

### Composables

* `useAuth`：登入狀態、角色、session 監聽
* `useSupabase`：Supabase client 單例
* `useRealtimeChannel(table, filter)`：封裝 postgres_changes 訂閱
* `useCapacity(sessionId)`：即時名額顯示（訂閱 + 定期重新查詢，僅供參考用）
* `useRegistrationCart`：報名購物車（前端暫存，結帳時才寫入資料庫）
* `useOrder` / `useCoupon` / `useLeave` / `useMakeup` / `useExternalMembership`
* `useAudit`（管理端）
* `useDateTz`：統一 Asia/Taipei 日期時間處理（包裝 `date-fns-tz` 或 `Luxon`）
* `useToast` / `useConfirm`：UX 共用元件

### Services（封裝 Supabase 查詢／RPC 呼叫，每個領域一個檔案）

`venueService`、`termService`、`classService`、`sessionService`、`registrationService`、`orderService`、`paymentService`、`couponService`、`leaveService`、`makeupService`、`externalMembershipService`、`specialEventService`、`doorAccessService`、`attendanceService`、`seatTransferService`、`auditService`、`reportService`（CSV 匯出）、`calendarService`（ICS/Google Calendar）

### Stores（Pinia）

* `authStore`：目前使用者、角色、session 狀態
* `uiStore`：Toast、Modal、Loading 狀態
* `cartStore`：報名購物車（僅結帳前的暫存 UI 狀態）

> 重要原則：Pinia store **不得**作為業務資料的正式來源。所有報名、付款、名額、請假、補課資料一律即時查詢/訂閱 Supabase，Store 僅快取當前畫面所需的展示資料，避免違反 MASTER_SPEC.md 第 35 節。

## 4.2 Backend Architecture

### Supabase Tables

詳見第 5 節 Database Schema Proposal（24 張表格 + 設計說明）。

### PostgreSQL Functions / RPC（建議清單）

所有「會影響名額、金額、優惠碼使用次數」的操作，一律透過 `SECURITY DEFINER` RPC 函式在單一交易內完成，並在函式內用 `SELECT ... FOR UPDATE` 鎖定相關列，避免競態：

* `rpc_create_order_full_term(...)` — 整期報名（可跨多班級）
* `rpc_create_order_single_sessions(...)` — 單堂報名（可多堂）
* `rpc_create_order_special_event(...)` — 特別活動報名（含套裝優惠計算）
* `rpc_confirm_payment(payment_id, ...)` — 管理員確認付款
* `rpc_create_leave(class_session_id)` — 建立請假（檢查 90 分鐘規則）
* `rpc_cancel_leave(leave_id)` — 取消請假（重新驗證名額狀態）
* `rpc_admin_override_leave(...)` — 管理員手動建立/修改請假
* `rpc_reserve_makeup(makeup_credit_id, target_session_id)` — 預約補課
* `rpc_confirm_makeup(reservation_id)` — 學生確認補課
* `rpc_approve_makeup(reservation_id, ...)` — 管理員核准/手動核准補課
* `rpc_adjust_makeup_capacity(class_session_id, delta, reason)` — 人工調整補課名額
* `rpc_mark_attendance(class_session_id, student_id, status)` — 點名
* `rpc_transfer_seat(registration_id, to_student_id, reason)` — 席位轉讓
* `rpc_get_session_capacity(class_session_id)` — 即時名額查詢（唯讀，供前台顯示）
* `rpc_register_external_membership(class_id)` — 運動中心學生資格登記
* `rpc_sweep_expired_makeup_reservations()` — 排程用：清理逾期未確認補課

**補課核准模式（已確認，第二輪修訂）**：`rpc_reserve_makeup` 第一版**全系統預設自動核准**（`approval_mode='auto'`，狀態直接進入 `confirmed`／`admin_approved` 相當的可上課狀態，不需人工介入），但管理員後台仍保留完整的手動能力：`rpc_approve_makeup` 支援管理員針對個案手動核准／駁回，另提供管理員直接建立補課（不需先透過學生走完整流程，對應規格第 19.2 節「老師已知道有人臨時無法上課」的情境）與 `rpc_adjust_makeup_capacity` 手動調整名額。第一版**不**依場地／班級／課堂分別設定不同核准模式，全域統一為自動核准，未來有需要再擴充為可分層設定。

### Edge Functions（視需要）

* SMS OTP 發送（若最終選擇 Phone+OTP 登入方案）
* ICS 行事曆檔案產生
* 大量 CSV 匯出（如資料量大到不適合前端直接組裝）
* 若 Supabase 專案不支援 `pg_cron`，改用 Edge Function + 外部排程（Vercel Cron Job）呼叫 `rpc_sweep_expired_makeup_reservations`

### Realtime Channels

* `class_sessions` / `registrations` / `makeup_reservations` 的 `postgres_changes`（依 venue/class 過濾，用於名額即時提示）
* `leave_requests`（本人 or 管理端全域）
* `announcements`（品牌設定/公告）
* `door_access`（公布事件，僅推播給有權限的訂閱者）

## 4.3 Authentication Architecture

### 4.3.1 Student Authentication — Supabase 原生 Phone + Password（已確認方案，第二輪修訂）

**更正說明**：第一輪報告誤判「Supabase Auth 原生不支援手機+密碼」，因而提出合成 Email／OTP／自訂 JWT 三個變通方案。重新查證 [Supabase 官方 Password-based Auth 文件](https://supabase.com/docs/guides/auth/passwords) 後確認：**Supabase Auth 原生支援以手機號碼作為身分識別、搭配密碼登入**，語法為：

```js
// 註冊
await supabase.auth.signUp({ phone: '+886912345678', password: '123456對應PIN' })

// 登入
await supabase.auth.signInWithPassword({ phone: '+886912345678', password: 'PIN' })
```

因此**撤回方案 A/B/C**，改採 Supabase 原生 Phone + Password 作為唯一實作路徑，PIN 即為 Supabase Auth 的 `password` 欄位，密碼雜湊、session、refresh token 皆由 Supabase 原生機制處理，完全符合「不得將 PIN 明碼存入前端」「不得使用前端假登入」的要求。以下依使用者要求的 8 個面向逐項分析：

**1. 註冊流程**

1. 學生於前台輸入手機號碼，前端即時正規化為 E.164 格式（見下方第 2 點）。
2. 學生設定 6 位數 PIN，前端先做基本檢查（是否為封鎖清單中的過度簡單組合，見 4.3.2 節），通過後才送出。
3. 前端呼叫 `supabase.auth.signUp({ phone: normalizedPhone, password: pin })`。
4. 資料庫 Trigger 監聽 `auth.users` 新增事件，自動建立對應的 `profiles` 列（`id = auth.uid()`、`phone = 正規化後的手機號碼`）並在 `user_roles` 指派 `student` 角色，前端不需要、也不應該自行寫入這兩張表。
5. 若第一版啟用簡訊驗證（見第 3 點），帳號需完成 `verifyOtp()` 才視為「已驗證」；若不啟用，帳號建立後即可直接登入。

**2. 電話格式標準化**

Supabase Phone Auth 要求 **E.164 格式**（例：`+886912345678`），而台灣使用者慣用輸入 `0912345678`。必須建立共用的正規化工具函式（例如 `normalizeTaiwanPhone()`），統一在註冊、登入、忘記密碼、管理員後台查詢學生等所有入口使用同一套規則（去除開頭 `0`、補上 `+886`），並將正規化後的格式同時存入 `auth.users.phone` 與 `profiles.phone`，避免「同一號碼因格式不同被系統誤判為兩個帳號」。

**3. 是否需要首次手機驗證（成本 vs 安全的取捨，仍需使用者確認，但不阻擋 Phase 1）**

Supabase 官方文件將手機驗證列為「可選但建議啟用」：啟用後需設定簡訊供應商（Twilio / MessageBird / Vonage 等，均有簡訊費用），使用者收到 6 位數簡訊碼並於 60 秒內用 `verifyOtp()` 完成驗證。

* **若啟用**：可確保手機號碼真實屬於本人，降低他人冒用手機號碼註冊的風險，但產生持續性簡訊費用與註冊摩擦。
* **若不啟用（建議第一版採用）**：省下簡訊費用、註冊體驗更順暢；殘餘風險是「任何人都可以用他人的手機號碼註冊帳號」。考量本系統的金流仍由管理員人工確認付款（規格第 12.2 節），即使有人冒用手機號碼註冊，也無法直接造成金錢損失，僅可能造成「該手機真正持有人日後無法用自己的號碼註冊」的困擾，可透過管理員後台人工核對（例如比對 LINE 暱稱、現場報到）作為簡訊驗證的替代把關手段。

建議第一版**不啟用**簡訊驗證以控制成本，待正式營運後依實際冒用情況決定是否加開。此為唯一保留給使用者的細節決策，但**不影響 Phase 1 專案骨架的建立**，可在 Phase 3 實作前才最終拍板。

**4. 忘記 PIN 流程**（已依使用者決策確認：第一版由管理員協助重設）

1. 學生透過現場或 LINE 告知管理員需要重設 PIN。
2. 管理員於後台輸入該學生手機號碼，觸發「重設密碼」動作。
3. 前端呼叫一個受保護的 Edge Function（而非直接在前端使用 Service Role Key），Edge Function 內部先驗證呼叫者的 JWT 角色確實為 `admin`，通過後才以 Service Role 呼叫 Supabase Auth Admin API `auth.admin.updateUserById(studentUserId, { password: newPin })` 設定新 PIN。
4. 此操作寫入 `audit_logs`（操作者、角色、時間、原因），**但不記錄新 PIN 明碼**。
5. 新 PIN 由管理員以口頭或 LINE 私訊等系統外管道告知學生，系統本身不寄送。

**5. 手機號碼回收風險**

Supabase 官方文件本身也提醒此風險：電信商可能回收停用門號並重新配發給其他人，理論上可能造成帳號接管。本系統的緩解因素：

* 密碼重設走「管理員人工協助」而非「自動簡訊 OTP 重設」，因此**沒有自動化的『用簡訊接管帳號』漏洞**——新門號持有者即使收得到簡訊，也無法單靠這一點重設舊帳號密碼。
* 唯一風險場景是新門號持有者若「碰巧知道或猜中」舊持有者的 6 位數 PIN 才能登入，機率極低但非零（見第 6-7 點的暴力破解防護）。
* 建議管理員後台在學生資料頁顯示「最後登入時間」，對長期未活動帳號可主動要求本人重新確認身份，作為額外緩解措施；此為 UX 建議，非強制要求。

**6. Rate Limiting**

由於 PIN 空間刻意設計得很小（6 位數字，且排除明顯簡單組合，實際有效組合數遠低於 100 萬），必須疊加兩層防護：

* Supabase 專案層級：`signInWithPassword` / `signUp` 端點本身有預設 Rate Limit，需於 Auth 設定調緊（例如降低單位時間內可嘗試次數）。
* 應用層級（Phase 3 需具體設計）：建議在 `profiles` 增加 `failed_login_count` 與 `locked_until` 欄位，登入失敗達一定次數（建議 5 次）後鎖定該帳號一段時間（建議 10-15 分鐘），並寫入 `audit_logs`。此為 Supabase 內建限制之外的額外防護，因為 Supabase 內建限制主要防止大量請求（例如防止單一 IP 灌爆），未必能針對「單一帳號被鎖定嘗試」做精準防護。

> **實作注意事項（第三輪修訂新增，Phase 3 設計時必須遵守）**：登入失敗當下，該學生**尚未取得合法 JWT**，因此絕對不可以讓「未登入的匿名前端」直接對 `profiles.failed_login_count` / `profiles.locked_until` 執行 `UPDATE`——即使只開放這兩個欄位的 `UPDATE` 權限給 `anon` 角色，也等於讓任何人可以任意竄改或惡意鎖定別人的帳號（例如惡意持續寫入使某學生的 `locked_until` 永遠是未來時間）。正確作法必須是下列其中一種安全後端控制流程，具體選擇留待 Phase 3 Authentication 設計階段決定：
> 1. **Edge Function**：登入嘗試改為呼叫一個 Edge Function（而非直接呼叫 `supabase.auth.signInWithPassword` 後才在前端處理失敗計數），由 Edge Function 以 Service Role 身份代為呼叫 Auth 並在同一次呼叫中更新失敗計數/鎖定欄位。
> 2. **安全 RPC（`SECURITY DEFINER`）**：提供一個限定用途、經過嚴格輸入驗證的資料庫函式（例如 `rpc_record_login_attempt(phone, success)`），僅允許寫入呼叫者對應手機號碼的那一列，且函式內部要有防濫用邏輯（例如同一 IP/裝置的呼叫頻率限制），不開放對 `profiles` 表的通用 `UPDATE` 權限。
> 3. **Supabase Auth 內建 Rate Limit + CAPTCHA + 額外後端防護三者疊加**，作為前兩者之外、多一層防線的縱深防禦，而不是取代前兩者。
>
> **明確禁止**：`profiles` 表不得對 `anon`（未登入）角色開放任何形式的直接 `UPDATE` 權限，即使只限定 `failed_login_count`/`locked_until` 兩個欄位也不允許；所有登入失敗計數與鎖定邏輯一律經由上述安全後端路徑處理。此事項已標記為 Phase 3 Authentication 設計時的強制檢查項，具體技術選型（Edge Function vs 安全 RPC）留待 Phase 3 決定。

**7. CAPTCHA / Abuse Prevention**

Supabase Auth 支援在 `signUp` / `signInWithPassword` 呼叫時附加 CAPTCHA token（hCaptcha 或 Cloudflare Turnstile），於 Supabase Dashboard 的 Auth 設定啟用。建議至少在「註冊」與「連續登入失敗後的重試」兩個情境啟用 CAPTCHA，降低自動化程式大量嘗試 6 位數 PIN 組合的風險。

**8. 與 `profiles` 表的關聯**

* `profiles.id` 仍對應 `auth.users.id`；不再需要第一輪方案 A 中的「合成 Email」欄位。
* `profiles.phone` 儲存正規化後的 E.164 格式，透過 Trigger 與 `auth.users.phone` 保持一致。
* 若第 3 點選擇啟用簡訊驗證，建議在 `profiles` 增加 `phone_verified_at timestamptz` 欄位，供後台辨識「已驗證」與「未驗證」帳號。

學生重新整理頁面後登入狀態維持：這是 Supabase Auth 的標準行為（透過 refresh token 安全儲存），與登入方案無關，Phone + Password 方案同樣滿足此需求。

### 4.3.2 PIN 規則（已確認，第二輪修訂新增）

依使用者最終決策：

1. PIN 為 **6 位數字**。
2. 禁止過度簡單的 PIN，至少封鎖以下型態（於前端與後端 RPC 雙重檢查，不可只在前端擋）：
   * 全部相同數字（`000000`、`111111`…`999999`）
   * 連續遞增／遞減（`123456`、`654321`、`012345`…）
   * 其他可依營運經驗擴充的常見弱密碼清單
3. PIN 不得以明碼存入 `profiles` 或任何自訂表，完全交由 Supabase Auth 的密碼機制（bcrypt 雜湊）處理——也就是說系統中**不應該存在任何一張表格有 PIN 明碼或可還原的欄位**。
4. 忘記 PIN：第一版由管理員協助重設（見 4.3.1 節第 4 點）。
5. 學生不可透過 LocalStorage 或前端暫存資料完成正式驗證，所有登入驗證必須經過 Supabase Auth 的 `signInWithPassword`。

**額外防暴力破解機制（已評估，建議採用）**：由於 6 位數字的密碼空間遠小於一般密碼建議長度，即使排除簡單組合，仍屬相對容易窮舉的範圍，因此除了上述規則本身，**必須**疊加 4.3.1 節第 6-7 點所述的 Rate Limiting、應用層登入失敗鎖定、CAPTCHA 三項機制，三者缺一不可，不可僅依賴「PIN 規則」本身作為唯一防線。此設計方向已確認，具體參數（鎖定次數、鎖定時長）留待 Phase 3 實作時依需要微調，不影響 Phase 1。

### 4.3.3 Admin Authentication

* 標準 Supabase Auth Email + Password（或 Magic Link）。
* **MFA 分階段確認（第二輪修訂）**：學生第一版不要求 MFA。管理員帳號分兩階段：Phase 3 先完成一般 Email+Password 的 Admin Auth（不強制 MFA，避免拖慢初期開發與上手門檻）；待 Phase 12（Realtime & Production Hardening）進行正式上線前的安全性複查時，**強制要求管理員帳號啟用 Supabase 內建 TOTP MFA** 才能繼續使用後台。此順序已確認，不再是待決策問題。
* 絕不在前端硬編碼密碼，絕不使用「Logo 連點」或隱藏網址作為安全機制（明確禁止事項，已於 `AI_INSTRUCTIONS.md` 第 11 節列出）。

### 4.3.4 Role Management

* 建立 `user_roles` 表（`user_id`, `role`），角色至少包含 `student`、`admin`。
* 新使用者註冊時，透過資料庫 Trigger（`on auth.users insert`）自動建立 `profiles` 列並指派 `student` 角色。
* `admin` 角色只能由現有管理員透過受保護的後台操作（RPC，限管理員呼叫）指派，不開放自助升級。

### 4.3.5 RLS Strategy

* 建立 `SECURITY DEFINER` 輔助函式 `is_admin()`（查詢 `user_roles`，繞過 RLS 遞迴問題），所有牽涉「本人或管理員」的政策皆呼叫此函式。
* Owner-based 政策套用於：`registrations`、`orders`、`order_items`、`payments`、`leave_requests`、`makeup_credits`、`makeup_reservations`、`external_student_memberships`（條件：`user_id = auth.uid() OR is_admin()`）。
* 公開瀏覽資料（`venues`、`terms`、`classes`、`class_sessions`、特別活動）：`SELECT` 對所有人開放但僅限 `is_active = true AND is_public = true`；`INSERT/UPDATE/DELETE` 僅限管理員。
* `door_access`：僅當學生對該 `class_session` 具備有效出席資格（已報名／已補課成功且當日未請假）時才可 `SELECT`，透過 `SECURITY DEFINER` 函式 `can_view_door_access(session_id)` 判斷，避免政策內出現複雜巢狀查詢造成效能問題與邏輯錯誤。
* `audit_logs`：僅管理員可 `SELECT`；`INSERT` 僅由資料庫函式/觸發器執行，不對任何角色開放直接 `INSERT`。
* `coupons`：不開放讓前端任意查詢完整優惠碼清單（避免暴力枚舉），優惠碼驗證透過 RPC（輸入代碼字串，回傳是否有效與折扣金額），管理員後台則可完整 `SELECT`。
* `idempotency_keys`：使用者僅能 `INSERT`/`SELECT` 自己建立的 key，不可 `UPDATE`（由 RPC 內部管理狀態轉換）。

---

# 5. Database Schema Proposal（初版資料模型）

> 本節為 **Schema 提案**，尚未執行任何 migration。所有型別為建議，Phase 2 實際建表時可依 Supabase/Postgres 慣例微調。金額一律使用 `numeric(10,2)`，時間一律使用 `timestamptz`，日期用 `date`。

## 5.1 設計上的關鍵決策（先說明，避免表格definition看起來武斷）

1. **統一報名表**：`registrations` 用 `registration_type` 欄位（`full_term` / `single_session` / `special_event_session`）統一涵蓋三種報名型態，而不是分成三張結構相似的表。理由：查詢「學生擁有哪些出席資格」時只需查一張表；缺點是部分欄位（如 `class_session_id`）依型態不同會是 nullable，需要用 `CHECK` 約束限制合理組合。此為建議，如果使用者偏好分表以求型別更嚴謹，也可在確認後調整（屬於待決策項目）。
2. **補課名額組成獨立保存**：`class_sessions` 保留 `base_makeup_capacity`（可從 `classes.default_base_makeup_capacity` 帶入，逐堂可覆蓋），人工調整另立 `capacity_adjustments` 表以保留每一筆調整的原因/操作者/時間（滿足第 22.2 節要求），當日請假數與已預約數則即時用 `COUNT()` 計算，不落地存成單一欄位。
3. **軟刪除為主**：`venues`、`terms`、`classes`、`class_sessions`、`coupons`、`special_events` 等主檔一律使用 `is_active` 狀態旗標，不做實體刪除；交易性資料（`orders`、`registrations`、`leave_requests` 等）一律只用狀態轉換（`active` / `cancelled` / …），不刪除列。
4. **所有防重複的唯一約束搭配 Partial Index**（例如 `WHERE status = 'active'`），確保「取消後可重新報名」不受阻擋，同時仍能防止「同時有兩筆有效紀錄」。

## 5.2 資料表清單

### `profiles`
* PK：`id uuid`（= `auth.users.id`）
* 欄位：`phone text UNIQUE NOT NULL`、`name text`、`line_id text`、`remit_last5 text`、`created_at`、`updated_at`
* Unique：`phone`
* Index：`phone`

### `user_roles`（對應規格中的 roles 概念）
* PK：`id uuid`
* FK：`user_id → profiles.id`
* 欄位：`role text CHECK (role IN ('student','admin'))`
* Unique：`(user_id, role)`
* Index：`user_id`

### `venues`
* PK：`id uuid`
* 欄位：`name text`、`address text`、`business_mode text CHECK (IN ('self_operated','external_center'))`、`is_active bool`、`is_public bool`、`created_at`
* Index：`business_mode`, `is_active`

### `terms`
* PK：`id uuid`
* FK：`venue_id → venues.id`
* 欄位：`name text`、`start_date date`、`end_date date`、`leave_rule_note text`、`is_active bool`
* Index：`venue_id`, `(start_date, end_date)`

### `term_cancelled_dates`（停課日期，獨立表以支援多筆）
* PK：`id uuid`
* FK：`term_id → terms.id`
* 欄位：`cancelled_date date`、`reason text`
* Unique：`(term_id, cancelled_date)`

### `classes`
* PK：`id uuid`
* FK：`venue_id → venues.id`、`term_id → terms.id`
* 欄位：`name text`、`weekdays int[]`（0-6，支援多個上課星期）、`start_time time`、`end_time time`、`capacity int`、`business_mode text`（繼承自 venue，冗餘存放以簡化查詢）、`full_term_price numeric(10,2)`、`single_session_price numeric(10,2)`、`default_base_makeup_capacity int DEFAULT 0`、`is_open_for_registration bool`、`is_active bool`
* Index：`(venue_id, term_id)`, `is_open_for_registration`

### `class_sessions`
* PK：`id uuid`
* FK：`class_id → classes.id`
* 欄位：`session_date date`、`start_at timestamptz`、`end_at timestamptz`、`status text CHECK (IN ('scheduled','cancelled'))`、`base_makeup_capacity int`（預設帶入 class 的預設值，可覆蓋）、`notes text`
* Unique：`(class_id, session_date)`
* Index：`class_id`, `session_date`, `start_at`

### `registrations`
* PK：`id uuid`
* FK：`student_id → profiles.id`、`class_id → classes.id`、`term_id → terms.id (nullable)`、`class_session_id → class_sessions.id (nullable)`、`special_event_session_id → special_event_sessions.id (nullable)`、`order_item_id → order_items.id`
* 欄位：`registration_type text CHECK (IN ('full_term','single_session','special_event_session'))`、`status text CHECK (IN ('active','cancelled','transferred_out','transferred_in'))`、`created_at`、`cancelled_at`、`cancelled_reason text`
* CHECK：依 `registration_type` 限制對應的 FK 必須非空（例如 `single_session` 時 `class_session_id` 不可為 null）
* Unique（Partial）：
  * `(student_id, class_id, term_id) WHERE registration_type='full_term' AND status='active'`
  * `(student_id, class_session_id) WHERE registration_type='single_session' AND status='active'`
  * `(student_id, special_event_session_id) WHERE registration_type='special_event_session' AND status='active'`
* Index：`student_id`, `class_session_id`, `status`

### `orders`
* PK：`id uuid`
* FK：`student_id → profiles.id`、`venue_id → venues.id NOT NULL`、`coupon_id → coupons.id (nullable)`
* 欄位：`status text CHECK (IN ('pending','confirmed','cancelled'))`、`subtotal_amount numeric(10,2)`、`discount_amount numeric(10,2)`、`total_amount numeric(10,2)`、`idempotency_key text`、`created_at`
* Unique：`idempotency_key`
* Index：`student_id`, `status`
* **設計確認（第二輪修訂，詳見第 11.3 節完整分析）**：`venue_id` 維持 `NOT NULL`，一張訂單只屬於一個場地。購物車若同時包含不同場地的項目，結帳時**依場地自動拆成多張獨立訂單**，各自有獨立的 `idempotency_key`。實務上此規則主要影響「自營教室」訂單，因為運動中心（`external_center`）場地本身不透過本系統收款，不會產生 `orders`/`payments` 資料。

### `order_items`
* PK：`id uuid`
* FK：`order_id → orders.id`
* 欄位：`item_type text CHECK (IN ('full_term_class','single_session','special_event_session','special_event_package'))`、`class_id (nullable)`、`term_id (nullable)`、`class_session_id (nullable)`、`special_event_session_id (nullable)`、`special_event_package_id (nullable)`、`unit_price numeric(10,2)`、`quantity int`、`subtotal numeric(10,2)`
* Index：`order_id`

### `payments`
* PK：`id uuid`
* FK：`order_id → orders.id`、`confirmed_by → profiles.id (nullable，須為 admin)`
* 欄位：`method text CHECK (IN ('bank_transfer','line_transfer','cash'))`、`amount numeric(10,2)`、`status text CHECK (IN ('pending','paid','rejected','cancelled'))`、`remittance_last5 text`、`payer_note text`、`confirmed_at timestamptz`、`created_at`
* Index：`order_id`, `status`

### `coupons`
* PK：`id uuid`
* 欄位：`code text UNIQUE`、`discount_type text CHECK (IN ('fixed','percentage'))`、`discount_value numeric(10,2)`、`valid_from timestamptz`、`valid_until timestamptz`、`usage_limit_total int`、`usage_limit_per_student int`、`min_spend numeric(10,2)`、`is_active bool`
* Unique：`code`

### `coupon_scopes`（優惠碼適用範圍，正規化取代單一 jsonb 欄位）
* PK：`id uuid`
* FK：`coupon_id → coupons.id`
* 欄位：`scope_type text CHECK (IN ('venue','class','term','special_event'))`、`scope_id uuid`
* Index：`(coupon_id)`, `(scope_type, scope_id)`

### `coupon_redemptions`
* PK：`id uuid`
* FK：`coupon_id → coupons.id`、`order_id → orders.id`、`student_id → profiles.id`
* 欄位：`discount_amount numeric(10,2)`、`created_at`
* Unique：`(coupon_id, order_id)`
* Index：`(coupon_id, student_id)`（用於檢查個人使用上限）

### `external_student_memberships`
* PK：`id uuid`
* FK：`student_id → profiles.id`、`class_id → classes.id`
* 欄位：`valid_from date`、`valid_until date (nullable)`、`status text CHECK (IN ('active','inactive'))`、`registered_at timestamptz`
* Unique（Partial）：`(student_id, class_id) WHERE status='active'`
* Index：`student_id`, `class_id`

### `leave_requests`
* PK：`id uuid`
* FK：`student_id → profiles.id`、`class_session_id → class_sessions.id`、`source_registration_id → registrations.id (nullable)`、`source_membership_id → external_student_memberships.id (nullable)`、`admin_id → profiles.id (nullable)`
* 欄位：`status text CHECK (IN ('active','cancelled'))`、`reason text`、`requested_at timestamptz`、`deadline_at timestamptz`（= session.start_at − 90 分鐘，建立時計算存檔）、`is_admin_override bool`、`admin_reason text`、`cancelled_at timestamptz`
* Unique（Partial）：`(student_id, class_session_id) WHERE status='active'`
* Index：`class_session_id`, `student_id`, `status`

### `makeup_credits`
* PK：`id uuid`
* FK：`leave_request_id → leave_requests.id UNIQUE`、`student_id → profiles.id`、`venue_id → venues.id`（場地隔離用）、`source_class_id`、`source_session_id → class_sessions.id`
* 欄位：`valid_from date`（= leave session date − 20 天）、`valid_until date`（+20 天）、`status text CHECK (IN ('available','used','expired','revoked'))`、`created_at`
* Index：`student_id`, `venue_id`, `status`, `valid_until`

### `makeup_reservations`
* PK：`id uuid`
* FK：`makeup_credit_id → makeup_credits.id`、`target_class_session_id → class_sessions.id`、`student_id → profiles.id`（冗餘存放，簡化唯一約束）、`approved_by → profiles.id (nullable)`
* 欄位：`status text CHECK (IN ('pending_confirmation','confirmed','admin_approved','rejected','expired_unconfirmed','attended','no_show','cancelled'))`、`approval_mode text CHECK (IN ('auto','manual'))`、`reserved_at`、`confirm_deadline_at`（= target session start_at − 1 小時）、`confirmed_at`、`approved_at`、`rejected_reason text`
* Unique（Partial）：
  * `(makeup_credit_id) WHERE status NOT IN ('cancelled','rejected','expired_unconfirmed')`（一張補課資格同時只能有一筆有效預約）
  * `(student_id, target_class_session_id) WHERE status NOT IN ('cancelled','rejected','expired_unconfirmed')`
* Index：`target_class_session_id`, `status`, `confirm_deadline_at`

### `special_events`
* PK：`id uuid`
* FK：`venue_id → venues.id`
* 欄位：`name text`、`description text`、`is_active bool`

### `special_event_sessions`
* PK：`id uuid`
* FK：`special_event_id → special_events.id`
* 欄位：`session_date date`、`start_time time`、`end_time time`、`start_at timestamptz`、`capacity int`、`single_price numeric(10,2)`、`is_active bool`
* Index：`special_event_id`, `session_date`

### `special_event_packages`
* PK：`id uuid`
* FK：`special_event_id → special_events.id`
* 欄位：`name text`、`min_sessions int`、`discount_type text CHECK (IN ('fixed','percentage','fixed_price'))`、`discount_value numeric(10,2)`、`is_active bool`

### `door_access`
* PK：`id uuid`
* FK：`class_session_id → class_sessions.id UNIQUE`
* 欄位：`password text`、`is_published bool`、`published_at timestamptz`、`notes text`、`updated_at`

### `attendance`
* PK：`id uuid`
* FK：`class_session_id → class_sessions.id`、`student_id → profiles.id`、`source_registration_id (nullable)`、`source_makeup_reservation_id (nullable)`、`marked_by → profiles.id`
* 欄位：`status text CHECK (IN ('present','absent','makeup_present','excused'))`、`notes text`、`marked_at timestamptz`
* Unique：`(class_session_id, student_id)`

### `seat_transfers`
* PK：`id uuid`
* FK：`registration_id → registrations.id`、`from_student_id → profiles.id`、`to_student_id → profiles.id`、`processed_by → profiles.id (nullable，管理員處理時填入)`
* 欄位：`transfer_type text CHECK (IN ('full_term','single_session'))`、`status text CHECK (IN ('completed','rejected'))`、`reason text`、`transferred_at timestamptz`
* **設計確認（第二輪修訂）**：系統**不處理**轉讓雙方之間的金流，已付款原則上不退款；`A`、`B` 私下的金錢往來不由本系統記錄或處理。系統只負責記錄轉讓資格本身（原學生、受讓學生、轉讓時間）、管理員處理紀錄、以及完整歷史稽核，因此本表不含任何金額欄位。
* **待留意（非阻擋 Phase 1 的小型待確認項）**：MASTER_SPEC.md 第 26 節目前未明確定義「轉讓是否需要管理員逐筆核准才能生效」還是「學生可自助轉讓、系統僅記錄」。Schema 設計上已預留 `processed_by` 為 nullable 以同時相容兩種流程，實際流程細節可於 Phase 4（Admin Foundation）或 Phase 5 確認後再定案，不影響 Phase 1-2。

### `capacity_adjustments`（補課名額人工調整，獨立稽核）
* PK：`id uuid`
* FK：`class_session_id → class_sessions.id`、`adjusted_by → profiles.id`
* 欄位：`adjustment_value int`（可正可負）、`reason text`、`created_at timestamptz`
* Index：`class_session_id`

### `audit_logs`
* PK：`id uuid`
* FK：`actor_id → profiles.id (nullable，系統動作為 null)`
* 欄位：`actor_role text`、`action text`、`entity_type text`、`entity_id uuid`、`before_data jsonb`、`after_data jsonb`、`reason text`、`created_at timestamptz`
* Index：`(entity_type, entity_id)`, `actor_id`, `created_at`

### `idempotency_keys`
* PK：`key text`（客戶端產生的 UUID）
* FK：`user_id → profiles.id`
* 欄位：`action_type text`、`request_hash text`、`response_snapshot jsonb`、`status text CHECK (IN ('processing','completed','failed'))`、`created_at`、`expires_at`
* Index：`user_id`, `expires_at`

> 註：`roles` 在上表以 `user_roles` 命名（多對多結構，未來若需要更多角色可直接擴充，不需改表結構）；MASTER_SPEC 第 43 節列出的表名會在實際 migration 階段對齊或說明命名差異。

## 5.3 Session Capacity Formula（正課容量計算，第二輪修訂新增）

詳細背景與範例見第 11.1 節，此處先給出 Schema 層級的結論：**所有會讀取或影響某堂課容量的 RPC，一律呼叫同一個資料庫函式 `fn_session_used_seats(session_id)`**，不允許任何 RPC 各自重新實作一次計算邏輯，避免公式在多處實作後逐漸產生落差（drift）。該函式回傳的「已使用名額」定義為：

```text
fn_session_used_seats(session_id) =
    該 class_session 對應班級/期別的有效整期報名人數（該學生當天未請假）
  + 該 class_session 的有效單堂報名人數（該學生當天未請假）
  + 該 class_session 的有效補課預約人數（狀態屬於 confirmed / admin_approved / attended）
```

`可用名額 = classes.capacity - fn_session_used_seats(session_id)`。任何寫入操作（新增單堂報名、新增補課預約）都必須在同一交易內先對該 `class_session`（或對應的鎖定用列）執行 `SELECT ... FOR UPDATE`，鎖定後才呼叫此函式重新計算，通過後才允許 `INSERT`，避免併發搶位（呼應第 7 節 Concurrency Risk Analysis 第 1、2 項）。

整期報名本身則使用不同的容量檢查層級：**整期報名在「報名當下」檢查的是該班級/期別的名額（`classes.capacity` vs 目前有效整期報名人數），而非個別某一堂課的即時名額**，因為整期報名代表對整個期別的常態出席權利。細節與範例見第 11.1 節。

> **補課名額必須同時受雙重限制（第三輪修訂新增，強制設計原則）**：`rpc_reserve_makeup` 不能只檢查第 22.1 節的補課配額公式（`base_makeup_capacity + 當日有效請假人數 + 人工調整 - 有效補課預約人數`），因為那個公式只反映「運動中心自行核算的補課配額」，並不知道教室當下**實際還有沒有物理座位**。若只看配額公式，可能發生配額顯示還有名額、但教室當堂實際座位已經被整期/單堂學生坐滿的超賣情況（尤其自營教室場地，整期/單堂學生與補課學生共用同一批物理座位）。因此**實際允許補課人數必須取兩者的最小值**：
>
> ```text
> 實際允許補課人數 = MIN(
>     補課配額剩餘名額,                              -- 第 22.1 節公式
>     classes.capacity - fn_session_used_seats(session_id)  -- 第 5.3 節公式，實體剩餘座位
> )
> ```
>
> 設計要求：
> 1. `rpc_reserve_makeup` 必須在同一交易內**同時**計算補課配額剩餘名額與 `fn_session_used_seats` 的實體剩餘座位，兩個條件都通過才允許新增 `makeup_reservations`。
> 2. 兩個公式都必須讀取**同一組鎖定後的即時資料**（對 `class_sessions` 該列 `SELECT ... FOR UPDATE` 之後，在同一交易內分別計算），不可以先算配額、交易結束後才另外檢查座位，否則兩次查詢之間可能被其他併發請求插隊而失去保護效果。
> 3. `fn_session_used_seats` 是第 5.3 節定義的單一計算來源，補課配額公式與物理座位公式**共用同一個函式**取得已使用人數，不允許補課功能自己另外實作一套計算邏輯，避免公式分裂導致超賣（呼應第 5.3 節「所有 RPC 一律呼叫同一個函式」的原則）。
> 4. 運動中心場地若本身沒有物理容量限制（例如借用的公共空間沒有固定座位上限），`classes.capacity` 可設定為一個足夠大的值使物理限制形同不生效，此時 `MIN()` 的結果會自然收斂為補課配額本身；但自營教室因為是本系統管理的固定教室，物理容量限制必須確實生效。

---

# 6. Security & RLS Strategy 摘要

已於第 4.3.4 節詳述，重點原則：

1. Auth 負責「你是誰」，RLS + Role 負責「你能做什麼」，兩者分離。
2. 所有牽涉金額/名額/優惠碼的寫入一律經由 `SECURITY DEFINER` RPC，RLS 僅作為最後一道防線（防止繞過前端直接呼叫 REST API 竄改資料）。
3. 稽核紀錄寫入路徑集中於資料庫函式，不對前端開放直接 `INSERT`，確保 `before/after` 快照的正確性不受前端竄改影響。
4. RLS 政策撰寫後，需要用不同角色（student A、student B、admin、匿名）分別測試「能看到什麼／不能看到什麼」，避免政策遺漏（見第 8 節建議測試策略）。

---

# 7. Concurrency Risk Analysis（完整版）

| # | 風險場景 | 建議防護機制 |
|---|---|---|
| 1 | 最後一位名額被多人同時搶（整期/單堂/特別活動報名） | RPC 內對 `class_sessions`（或對應的鎖定用列）執行 `SELECT ... FOR UPDATE`，鎖定後於同一交易內 `COUNT()` 目前有效報名數並與 `capacity` 比較，通過才 `INSERT` |
| 2 | 補課名額被多人同時搶 | 同上，鎖定 `class_sessions` 對應列，交易內同時計算「補課配額公式」與「實體剩餘座位公式」，取兩者最小值後再判斷是否可預約（雙重限制，詳見第 5.3 節） |
| 3 | 優惠碼超過總使用上限 / 個人使用上限 | RPC 內鎖定 `coupons` 列，交易內 `COUNT(coupon_redemptions)` 判斷是否超限，通過才寫入 `coupon_redemptions` |
| 4 | 請假取消時，名額已被補課學生使用 | **已確認正式規則**：`rpc_cancel_leave` 需先查詢對應 `makeup_credits`/`makeup_reservations` 是否已進入 `confirmed`/`admin_approved`/`attended` 等已使用狀態；**若已使用，直接拒絕取消請假**（回傳明確錯誤訊息，不允許前端繞過），並於 UI 提示學生「該堂課名額已由其他學生補課使用，如有特殊情況請聯繫管理員」。管理員仍可透過管理端的例外處理機制（第 15.2 節 Admin Manual Exception）人工介入，但此路徑必須留下稽核紀錄。此規則已同步寫入 `MASTER_SPEC.md` 第 15.3 節。 |
| 5 | 重複送出（連續點擊/網路重試）造成重複訂單、重複補課預約、重複扣優惠碼 | `idempotency_keys` + 客戶端產生的請求 UUID，RPC 開頭先檢查 key 是否已處理，已處理則直接回傳先前結果 |
| 6 | 補課「逾時未確認」與「即時查詢可用名額」競態 | 排程（`pg_cron` 或外部 Cron）定期將逾期未確認的預約標記為 `expired_unconfirmed` 並記錄稽核；同時查詢可用名額時即時排除已逾期但尚未被排程處理的預約（雙重保險） |
| 7 | 席位轉讓與原報名狀態不一致 | `rpc_transfer_seat` 需在同一交易內同時處理「原報名標記為 transferred_out」與「新建 transferred_in 報名」，避免中途失敗造成資料不一致 |

---

# 8. Recommended Development Roadmap

依目前專案狀態（完全空白）重新確認 Phase 順序，基本維持 MASTER_SPEC.md 第 44 節的規劃，並將以下兩項排序調整由「建議」正式轉為**已確認**：

## 8.1 已確認的排序調整

1. **`audit_logs` 與 `idempotency_keys` 提前到 Phase 2（Database Schema）建立**，而不是留到 Phase 12 才處理。理由：Phase 5（報名）、Phase 6（付款/優惠碼）、Phase 8-9（請假/補課）從一開始就需要呼叫會寫入稽核紀錄與檢查 idempotency key 的 RPC，若這兩張表延後到 Phase 12 才建立，前面所有 Phase 的 RPC 都要重寫一次。
2. **測試工具與最小測試框架提前到 Phase 1 建立**（Vitest + Supabase CLI 本機開發環境；Playwright 於後續 Phase 逐步補上 e2e 案例），讓 Phase 2 起的每個 Phase 都能逐步累積測試，而不是把所有測試集中留到 Phase 13 才寫，降低最後階段的風險與工作量。第 8.3 節列出 9 項必須涵蓋的高風險測試案例與對應 Phase。

## 8.2 Phase 清單（確認後版本）

| Phase | 名稱 | 內容重點 |
|---|---|---|
| 0 | Project Audit & Implementation Planning | 本報告（已完成） |
| 1 | Project Foundation | Vue3+TS+Vite+Tailwind+Router 骨架、Supabase Client、環境變數、（建議）測試框架安裝 |
| 2 | Database Foundation | `profiles`/`user_roles`/`venues`/`terms`/`classes`/`class_sessions` + FK/Index/RLS 基礎、（建議）`audit_logs`/`idempotency_keys` |
| 3 | Authentication & Authorization | 學生登入方案（待第 9 節決策後實作）、管理員登入、Role 管理、RLS 政策 |
| 4 | Admin Foundation | Admin Layout、Dashboard、場地/期別/班級/課堂管理介面 |
| 5 | Student Frontend & Registration | 課程瀏覽、整期報名、多班報名、單堂報名、訂單建立（含 RPC + 併發保護） |
| 6 | Payment & Coupons | 付款紀錄、管理員付款確認、優惠碼系統、伺服器端價格驗證 |
| 7 | External Student Membership | 運動中心學生登記、資格驗證 |
| 8 | Leave System | 請假、90 分鐘規則、管理員例外、取消請假（含名額重新驗證）、稽核 |
| 9 | Makeup System | 補課資格（±20天）、場地隔離、同班級規則、預約、確認、核准（自動/手動）、運動中心公式 |
| 10 | Special Events | 特別活動、多堂報名、套裝優惠、多堂折扣 |
| 11 | Door Access & Attendance | 每堂課門禁密碼、公布狀態、學生查看規則、點名 |
| 12 | Realtime & Security Hardening | Supabase Realtime、併發防護複查、Idempotency 複查、錯誤處理、安全性/RLS 總複查 |
| 13 | Production Testing | 報名/搶位/優惠碼/付款/請假/補課/運動中心公式/特別活動/驗證/授權/RLS 完整測試 |

> 每個 Phase 開始前，依 `AI_INSTRUCTIONS.md` 第 5 節流程執行：Inspect → Analyze → Plan → Implement（僅限已核准範圍）→ Validate → Report。每個 Phase 結束後停止，等待下一步指示，不自動連續執行多個 Phase。

## 8.3 高風險測試清單（已確認，第二輪修訂新增）

依使用者確認，測試策略採用 **Vitest（前端單元測試）+ Supabase CLI（本機資料庫/RPC 測試）+ Playwright（e2e）**，並至少必須涵蓋以下 9 項高風險測試案例。每項標註主要撰寫時機（該功能完成的 Phase）與最終複查時機（Phase 13 Production Testing 一律重跑一次完整回歸）：

| # | 測試案例 | 主要撰寫 Phase |
|---|---|---|
| 1 | 多人同時搶最後一個正課名額 | Phase 5（首次撰寫）／Phase 13（回歸） |
| 2 | 多人同時搶最後一個補課名額 | Phase 9／Phase 13 |
| 3 | 優惠碼總使用上限併發 | Phase 6／Phase 13 |
| 4 | 優惠碼個人使用上限併發 | Phase 6／Phase 13 |
| 5 | 重複點擊造成重複訂單（Idempotency） | Phase 5／Phase 13 |
| 6 | 請假取消但名額已被補走（應拒絕取消） | Phase 8／Phase 13 |
| 7 | 補課逾期未確認（應自動轉為 expired） | Phase 9／Phase 13 |
| 8 | RLS：Student A 不能讀取 Student B 的資料 | Phase 3（建立 RLS 後即測）／Phase 12／Phase 13 |
| 9 | 非 Admin 不能修改付款狀態 | Phase 6（付款功能完成後）／Phase 12／Phase 13 |

## 8.4 CSV 匯出與行事曆整合的排程（已確認，第二輪修訂新增）

* **CSV 匯出不再視為 Nice-to-have**，確認為正式上線前必須完成的項目。建議採取「隨相關管理功能同步完成」的方式漸進實作，而非集中留到最後：例如 Phase 5（報名管理）完成後即加上「報名名冊 CSV 匯出」、Phase 4（學生管理）完成後加上「學生名冊 CSV 匯出」。最晚不得晚於 Phase 13（Production Testing）開始前完成。
* **Google Calendar / ICS 行事曆整合**排在核心報名、請假、補課功能之後，建議安排於 Phase 10（Special Events）之後、Phase 12 之前的空檔實作，不阻擋核心系統開發進度。

---

# 9. Questions Requiring Human Decision（待決策問題，第二輪修訂版）

## 9.1 已解除的問題（原編號對照）

| 原編號 | 問題 | 解除方式 |
|---|---|---|
| Q1 | 學生登入技術方案 A/B/C 三選一 | 改用 Supabase 原生 Phone + Password，見第 4.3.1 節 |
| Q2 | PIN 規則 | 6 位數字＋弱 PIN 黑名單＋管理員協助重設，見第 4.3.2 節（另衍生出防暴力破解的工程待辦，非商業決策） |
| Q3 | 請假取消 vs 補課名額已被使用 | **確認為正式規則：名額已被使用時禁止取消請假**，已同步寫入 `MASTER_SPEC.md` 第 15.3 節 |
| Q4 | 補課核准模式預設值 | 全域預設自動核准，管理員保留手動核准/駁回/建立/調整能力，第一版不分場地/班級/課堂設定，見第 4.2 節 |
| Q5 | `pg_cron` 可用性是否阻擋開發 | 確認優先採用 Supabase Cron/`pg_cron`，不阻擋任何 Phase，待專案建立後於 Phase 9 前驗證即可 |
| Q6 | 運動中心 `base_makeup_capacity` 設定層級 | 確認為班級層級預設值＋課堂層級可覆蓋 |
| Q7 | 席位轉讓的金流規則 | 確認系統不處理金流、不退款，只記錄轉讓資格與稽核，見第 5.2 節 `seat_transfers` |
| Q8 | 管理員是否需要 MFA | 確認分階段：Phase 3 一般 Auth，Phase 12 強制啟用 TOTP MFA |
| Q9 | CSV/Calendar 優先順序 | 確認 CSV 為上線前必須項目、隨功能同步完成；Calendar 可排在核心功能之後，見第 8.4 節 |
| Q10 | 測試工具選擇 | 確認採用 Vitest + Supabase CLI + Playwright，並新增 9 項高風險測試清單，見第 8.3 節 |
| Q11 | Phase 排序調整 | 確認採用，見第 8.1 節 |

## 9.2 仍待留意的項目（不阻擋 Phase 1，僅供追蹤）

1. **首次手機簡訊驗證是否啟用**（第 4.3.1 節第 3 點）：屬於成本 vs 安全的持續取捨，建議第一版不啟用，可於 Phase 3 實作前才最終拍板，不影響 Phase 1 專案骨架。
2. **席位轉讓的核准流程型態**（第 5.2 節 `seat_transfers` 備註）：MASTER_SPEC.md 第 26 節尚未明確定義「是否需要管理員逐筆核准轉讓才生效」，Schema 已預留彈性，實際流程可於 Phase 4-5 確認，不影響 Phase 1-2。

以上兩項均為細節層級的待確認事項，性質上不同於第一輪報告的 11 個問題（那些會直接影響 Schema 或 Auth 架構的根本設計），因此**不再視為阻擋 Phase 1 啟動的條件**。

---

# 10. 是否可以進入 Phase 1？（第二輪修訂版結論）

**本報告仍只完成 Phase 0 的修訂，尚未開始 Phase 1、尚未撰寫任何正式程式碼、尚未建立任何資料庫 migration，依使用者指示在此停止，等待進一步確認。**

以下是關於「Phase 1 是否已無阻礙」的分析，供使用者參考：

* 第一輪報告中真正會影響 Phase 2/3 根本架構的關鍵問題（學生登入技術方案）**已在本輪解除**——確認採用 Supabase 原生 Phone + Password，不再需要在合成 Email、簡訊 OTP、自訂 JWT 之間三選一。
* 本輪確認的其餘 9 項決策（PIN 規則、請假取消規則、補課核准模式、Cron 策略、運動中心基礎名額層級、席位轉讓規則、Admin MFA 時機、CSV/Calendar 排程、Testing 策略、Phase 排序）多數影響的是 Phase 3 之後（Authentication、業務邏輯 RPC、後台功能）的實作細節，**不影響 Phase 1（專案骨架：Vue3+TS+Vite+Tailwind+Router+Supabase Client+環境變數+測試框架安裝）本身的建立方式**。
* 第 9.2 節列出的 2 項仍待留意事項，同樣性質上屬於「可在對應 Phase 實作前才拍板」的細節，不影響 Phase 1。

**結論：就 Phase 1 的範圍而言，目前沒有尚未解除、會實質影響 Phase 1 實作方式的阻擋性問題。** 但依照使用者本次的明確指示「完成後停止，不要開始 Phase 1」，本報告在此停止，等待使用者在確認本修訂版內容無誤後，另行下達開始 Phase 1 的指示。

---

# 11. Capacity, Atomicity & Multi-Venue Order Model（資料庫設計深入分析，第二輪修訂新增）

本節回應使用者提出的三個資料庫設計問題（原文標示 A/B/C）。

## 11.1 問題 A：整期報名如何影響每一堂課的正課容量計算

**核心原則：容量分兩層檢查，且所有讀取/寫入都必須經過同一套計算邏輯（第 5.3 節的 `fn_session_used_seats`），不可讓不同 RPC 各自實作一份。**

**第一層：整期報名的名額檢查（發生在報名當下，檢查對象是「班級/期別」而不是單一堂課）**

整期報名代表學生取得該班級在整個期別內、所有未請假課堂的常態出席權利，因此整期報名的名額限制，本質上是「這個班級整期最多能收幾位常態學生」，而不是逐堂課檢查。實作上：

```text
可整期報名人數 = classes.capacity - count(該 class_id + term_id 目前狀態為 active 的整期報名)
```

在 `rpc_create_order_full_term` 內對 `classes` 該列（或對應鎖定用列）執行 `SELECT ... FOR UPDATE`，鎖定後重新計算上式，通過才允許新增整期報名。

**第二層：單一堂課的即時容量（發生在單堂報名、補課預約時，檢查對象是特定 `class_session`）**

一旦學生取得整期報名資格，他在該期別內「每一堂課」都會自動計入該堂課的已使用人數（除非當天請假）。因此第 5.3 節定義的 `fn_session_used_seats(session_id)` 公式中，第一項（整期報名人數）**已經涵蓋**了整期學生對單堂容量的占用，計算方式是：

```text
該堂課已使用人數
  = count(該班級+期別、狀態 active 的整期報名，且該學生對這堂課沒有 active 請假)
  + count(該堂課本身、狀態 active 的單堂報名，且該學生對這堂課沒有 active 請假)
  + count(該堂課的補課預約，狀態屬於 confirmed/admin_approved/attended)

該堂課剩餘正課名額 = classes.capacity - 該堂課已使用人數
```

**具體範例**：某班級 `capacity = 20`。目前有 15 位整期報名學生，其中 1 位對某週三的課請假。該週三另外有 2 位單堂報名學生、1 位補課預約學生。則該週三這堂課的已使用人數 = (15-1) 整期學生 + 2 單堂學生 + 1 補課學生 = 17，剩餘名額 = 20 - 17 = 3。此時若有第 4 位單堂報名或第 2 位補課申請進來，RPC 必須即時算出「還有 3 個名額」並允許，第 5 個申請則必須被拒絕。

**設計啟示**：`rpc_create_order_single_sessions`、`rpc_reserve_makeup` 這兩個會影響「單一堂課」容量的 RPC，都必須呼叫同一個 `fn_session_used_seats`；而 `rpc_create_order_full_term` 則呼叫檢查「班級整期容量」的獨立邏輯。兩層邏輯必須明確區分，不可混用，否則會出現「整期名額算兩次」或「單堂名額漏算整期學生」的錯誤。

## 11.2 問題 B：整期報名一次報多班，其中一班已滿時的行為

**已確認：採用 Atomic Transaction（全部成功或全部失敗）**，與使用者的預設傾向一致。

設計要點：

1. `rpc_create_order_full_term` 接收一個班級陣列（例如學生想同時報名 A、B、C 三個班級），整個函式在單一資料庫交易內執行。
2. 為避免多個學生同時搶多個班級造成死鎖，函式內對所有牽涉到的 `classes` 列，**先依 `class_id` 排序後再依序執行 `SELECT ... FOR UPDATE`**（固定鎖定順序是避免死鎖的標準做法）。
3. 依序檢查每個班級是否還有整期名額（第 11.1 節第一層公式）。**只要有任何一個班級名額不足，就以 `RAISE EXCEPTION` 中止函式**，因為函式內的操作都在同一個 Postgres 交易中，例外會使該交易內先前已執行的所有 `INSERT`（包含已成功鎖定/插入的 A、B 班級報名）全部自動回滾（ROLLBACK），不需要額外手動清除，確保「A、B 有名額但 C 已滿」時，A、B 也不會產生報名紀錄或訂單。
4. 前端應在結帳前先用唯讀查詢（`rpc_get_session_capacity` 或直接查詢班級可用名額）做預先提示，讓學生在送出前就知道「C 班可能已滿」，但**最終正確性一律以後端交易結果為準**，前端預先提示只是體驗優化，不能取代後端的即時重新驗證。
5. 失敗時，前端應清楚告知學生「因為 OO 班級名額已滿，本次報名（含 A、B、C）全部未成功」，並允許學生調整購物車內容後重新送出。

## 11.3 問題 C：Orders 的 `venue_id` 與跨場地購物車

**已確認：不同場地自動拆成不同 `orders`**，與使用者的預設傾向一致，理由也與規格本身吻合：自營教室與運動中心的付款規則本來就不同（運動中心不透過本系統收款，甚至不會產生 `orders`/`payments`）。

設計要點：

1. `cartStore`（前端購物車）允許同時存放來自不同場地的項目（例如同時想整期報名自營教室的 Zumba 班，又想單堂報名另一個自營教室的假日快閃課——注意：運動中心項目不會出現在購物車的「報名」流程中，運動中心走的是 `external_student_memberships` 登記流程，不經過 `orders`）。
2. 結帳時，前端先依 `venue_id` 將購物車內容分組，對**每一組場地各自呼叫一次**對應的訂單建立 RPC（`rpc_create_order_full_term` / `rpc_create_order_single_sessions` / `rpc_create_order_special_event`），因此一次結帳動作可能產生 N 筆獨立的 `orders`（N = 購物車涵蓋的場地數）。
3. 每一組場地各自的呼叫都帶自己獨立產生的 `idempotency_key`（前端在分組當下就為每一組產生一個 UUID），確保任一場地的重試不會影響到其他場地的訂單。
4. 每筆 `orders` 各自對應該場地的付款方式與付款說明（銀行轉帳／LINE／現金），在 UI 上应清楚呈現「本次操作將產生 2 筆訂單，請分別完成付款」，避免學生誤以為只需付一筆錢。
5. 優惠碼的 `coupon_scopes`（第 5.2 節）本來就是以場地/班級/期別/活動為適用範圍，訂單拆分後，優惠碼折扣計算與 `coupon_redemptions` 的建立也自然地各自歸屬到對應場地的那筆訂單，不會有跨訂單套用同一張優惠碼折抵金額的混淆問題。

**跨場地拆單的部分成功處理（第三輪修訂新增，強制設計原則）**：必須明確認知**跨場地結帳不是一個全域 Atomic Transaction**——每個 venue 各自呼叫一次獨立的訂單建立 RPC，因此每個 venue 的 Order 各自是獨立的 Atomic Transaction（呼應第 11.2 節「單一 venue 內的多班級整期報名」才是 Atomic），venue 之間彼此不互相保證。也就是說，「Venue A 的訂單成功、Venue B 的訂單失敗」是正常且必然要處理的情境，不是例外錯誤。前端與後端必須依下列原則設計：

1. **前端 UI 必須逐一顯示每個 venue 的成功／失敗狀態**，不可以用單一整體的「成功」或「失敗」訊息概括（例如用一個清單呈現：「自營教室 A — 訂單建立成功，請完成付款」「運動中心相關項目 — 因故失敗，請重試」），讓學生清楚知道哪些場地已經確定、哪些還沒有。
2. **成功的 Order 不得因其他 venue 失敗而重複建立或被回滾**：前端呼叫是「每個 venue 各自獨立的 RPC 呼叫」，A 呼叫成功後其資料庫交易已經提交（COMMIT），即使後續 B 呼叫失敗，也絕不能因此對 A 的訂單做任何回滾、取消或重新呼叫的動作。
3. **失敗的 venue 可以單獨重試**：前端應保留「僅重試失敗場地」的操作路徑（而不是要求學生從頭重新結帳所有場地），重試時沿用原本該 venue 分組已產生的 `idempotency_key`（見下一點），確保重試是安全的。
4. **每個 venue 維持自己獨立的 `idempotency_key`**：如第 11.3 節第 3 點所述，每組場地在前端分組當下各自產生一個 UUID；重試失敗的 venue 時，必須重複使用同一把 key（而不是重新產生新的），讓後端的 idempotency 檢查機制能正確判斷「這是同一筆請求的重試」還是「這是一筆全新的請求」。
5. **優惠碼 redemption 必須避免因重試造成重複使用**：由於 `coupon_redemptions` 表以 `(coupon_id, order_id)` 為 Unique 約束（第 5.2 節），而 `order_id` 只有在該 venue 的訂單交易成功建立後才會存在，因此重試失敗的 venue 時，若該次重試最終建立的是「同一筆邏輯訂單」（透過 idempotency_key 判斷為重試而非新請求），RPC 內部必須回傳先前已處理的結果而不是重新扣一次優惠碼使用次數；若 idempotency 檢查判斷這是全新請求，才會走正常的優惠碼驗證與扣減流程。這與第 9.1 節已確認的 Idempotency 機制（`idempotency_keys` 表）是同一套保護機制的延伸應用，不需要另外設計新機制。

---

# End of PHASE_0_AUDIT_REPORT.md
