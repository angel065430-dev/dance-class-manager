# REGISTRATION_MVP_PLAN.md

# Registration MVP Implementation Plan

> **狀態：📋 規劃文件，等待你確認。尚未修改任何資料庫 schema、尚未建立任何 migration、尚未撰寫任何程式碼。**
> 本文件回應你提出的「報名功能優先」方向調整，重新規劃 Phase 3／Phase 4 範圍，目標是用最短時間讓「學生登入 → 瀏覽期課 → 一次選多堂 → 送出報名 → 管理員看到結果」這條路徑真正可用。

---

## 0. 前提（Inspect / Analyze 摘要）

已重新核對 `MASTER_SPEC.md`、`AI_INSTRUCTIONS.md`、`PHASE_0_AUDIT_REPORT.md`，以及 Phase 2 已完成並通過真正 Supabase Local 驗收的資料庫結構（`profiles`／`user_roles`／`venues`／`terms`／`classes`／`class_sessions`／`audit_logs`／`idempotency_keys`，8 張表 + RLS 基礎）。

目前完全沒有：登入/註冊前端、報名相關資料表、任何報名 RPC、Admin 前台任何頁面。以下規劃基於「不違反 `AI_INSTRUCTIONS.md` 強制規則（Row-level Security、後端驗證名額、Idempotency、稽核紀錄、絕不信任前端最終價格/名額）」為前提，在此前提下砍掉一切非報名路徑必要的範圍。

---

## A. Phase 3／Phase 4 重整方案

### 原則

> 只保留「讓學生能安全送出期課報名、管理員能看到結果」這條路徑上的必要節點，其餘全部移到 P1／P2。

### 對照表

| 原 Phase | 原內容 | 本次調整 |
|---|---|---|
| Phase 3：Authentication | 學生 Phone+Password、Admin Email+Password、Role 管理、RLS | **保留但瘦身**：signup/login 核心流程保留；SMS OTP、弱 PIN 的 Auth Hook 強制封鎖、登入失敗鎖定機制（`failed_login_count`/`locked_until`）**全部移到 P1**（理由見下方「明確延後項」） |
| Phase 4：Admin Foundation | Admin Layout、Dashboard、場地/期別/班級/課堂完整 CRUD 管理介面 | **大幅瘦身**：完整 CRUD 表單全部移到 P1，改用「SQL Seed Script／Supabase Studio 手動建資料」開放你要出租確認的那幾堂課；P0 只做「Admin 登入 + 報名清單唯讀頁」 |
| Phase 5（原）：Student Frontend & Registration | 課程瀏覽、整期/多班/單堂報名、Orders | **提前**：期課（整期）報名的必要子集**提前併入 P0**；單堂報名（Single-Session）本體功能延後到 P1（採你提出的方案 A：資料庫先預留、UI 先不做，理由見 B 節） |

### 明確提前的項目

1. `registrations` / `orders`（MVP 瘦身版）資料表與 RLS。
2. `rpc_submit_full_term_registrations`（多堂期課原子報名 RPC）。
3. 公開課程瀏覽頁（唯讀，任何人可看，對應 Phase 4 原本規劃但範圍很小）。
4. 學生「我的報名」頁（唯讀清單）。
5. Admin 報名清單頁（唯讀）。

### 明確延後的項目（不影響學生完成報名）

| 項目 | 延後理由 |
|---|---|
| SMS 首次手機驗證（OTP） | Phase 0 §4.3.1 本就建議第一版不啟用；與能否報名無關 |
| 弱 PIN 的伺服器端 Auth Hook 強制封鎖 | 技術可行性尚待查證（見下方風險 E 節）；P0 先用前端封鎖 + Supabase 內建 Rate Limit 作為過渡防護，殘餘風險可接受（付款仍是人工核對，冒用手機號碼無法直接造成金錢損失） |
| `failed_login_count`/`locked_until` 登入鎖定 | Phase 2 已刻意不提前建這兩個欄位（避免「欄位存在但沒有保護路徑」的空窗期）；P0 沿用此判斷，欄位與其安全寫入路徑（Edge Function 或 Hook）**一起**在 P1 實作，不拆開做 |
| Admin 完整 CRUD（場地/期別/班級/課堂管理表單） | 用 SQL Seed Script 或 Supabase Studio 手動建立你要開放報名的那幾堂課即可達成「盡快開放報名」的目的，不需要等表單做完 |
| 單堂報名 UI + RPC | 依你提出的方案 A，資料庫層先預留擴充能力（見 B 節），UI 與 RPC 邏輯本身延後 |
| 付款狀態流程（`payments`、Admin 確認付款） | 你目前的目標是「確認需求與人數」，不是收款；付款欄位可先用 `remit_last5` 記錄資訊性資料，正式收款流程延後 |
| 優惠碼、席位轉讓、請假、補課、特別活動、門禁、點名、Realtime | 與原 Roadmap Phase 6-11 相同順序，未受影響 |
| CSV 匯出、Google Calendar 整合 | Phase 0 §8.4 仍要求「正式上線前」必須完成，但「正式上線」與「開放這次報名意向調查」是兩個里程碑，CSV 匯出可以在 P1 補上 |
| Admin MFA 強制 | 原規劃就是「正式上線前」才強制，不受本次調整影響，維持原位置 |

---

## B. 報名 MVP 的完整資料模型

### 是否新增資料表：新增 `orders`、`registrations` 兩張（MVP 瘦身版），不新增 `order_items`

**理由**：Phase 0 §5.2 的 `order_items` 主要是為了讓「整期／單堂／特別活動／套裝」四種不同商品型態共用同一張明細表。MVP 只有「期課」一種商品型態，`registrations` 本身已經是「一筆 = 一個學生對一個班級的期課報名」，直接拿它當明細用即可，不需要再疊一層 `order_items`。等 P1 真的要做單堂報名／特別活動時，再評估是否需要補上 `order_items`——這是「延後而非放棄」，不影響現在的正確性。

### `orders`（訂單，MVP 瘦身版：批次容器，不含付款流程）

```text
id                uuid PK
student_id        uuid REFERENCES profiles(id)
venue_id          uuid REFERENCES venues(id) NOT NULL   -- 沿用 Phase 0 §11.3 已確認規則：一張訂單一個場地
status            text CHECK IN ('confirmed','cancelled')  -- MVP 不做 pending，送出即成立
subtotal_amount   numeric(10,2)   -- 提交當下伺服器端計算的期課價格總和（快照，非信任前端）
total_amount      numeric(10,2)   -- MVP 等同 subtotal（無折扣/優惠碼）
idempotency_key   text UNIQUE     -- 沿用 Phase 2 已建立的 idempotency_keys 機制
created_at        timestamptz
```

### `registrations`（報名紀錄，MVP 瘦身版，但保留單堂擴充能力）

```text
id                 uuid PK
student_id         uuid REFERENCES profiles(id)
class_id           uuid REFERENCES classes(id)
term_id            uuid REFERENCES terms(id)              -- 從 class 帶入，用於唯一約束
order_id           uuid REFERENCES orders(id)
class_session_id   uuid REFERENCES class_sessions(id) NULL  -- MVP 恆為 NULL，保留給未來單堂報名
registration_type  text CHECK IN ('full_term','single_session') DEFAULT 'full_term'
status             text CHECK IN ('active','cancelled')
created_at         timestamptz
cancelled_at       timestamptz NULL
cancelled_reason   text NULL

-- 防重複報名（真正的防線是資料庫約束，RPC 內的檢查只是為了給出好懂的錯誤訊息）
UNIQUE (student_id, class_id, term_id)
  WHERE registration_type = 'full_term' AND status = 'active'
```

**一位學生一次報多堂課時，資料如何保存**：一次提交 = 1 筆 `orders` + N 筆 `registrations`（每個勾選的班級一筆），全部指向同一個 `order_id`，方便之後追溯「這幾堂課是同一次一起報的」。

**如何避免重複報名**：上方的 Partial Unique Index 是最終防線（資料庫層級保證，即使繞過前端或 RPC 也擋得住）；RPC 內會先做一次友善檢查，避免學生直接看到裸的資料庫錯誤訊息。

**如何保留未來單堂報名的擴充能力**：`registration_type` 欄位與 nullable 的 `class_session_id` 從一開始就存在（採你提出的方案 A）。等 P1 要做單堂報名時，只需要新增對應的 RPC 與前端 UI，**不需要修改這兩張表的結構**，也不影響 MVP 期間已經產生的期課報名資料。

### RLS（沿用 Phase 2 已建立的 `is_admin()` 模式）

* `orders`：`SELECT` 限本人或 Admin；不對 `anon`/`authenticated` 開放任何 `INSERT`/`UPDATE`/`DELETE`，寫入完全透過下方的 `SECURITY DEFINER` RPC（與 `audit_logs`/`idempotency_keys` 已用的模式一致）。
* `registrations`：規則同上。

### 名額顯示（唯讀，供公開瀏覽頁使用）

新增一個 `SECURITY DEFINER` 唯讀函式 `fn_class_remaining_seats(class_id)`，回傳 `classes.capacity - 目前有效期課報名數`，`anon` 可呼叫。前端瀏覽頁用它顯示「剩餘名額」（僅供參考，真正把關在報名 RPC 內），呼應 `AI_INSTRUCTIONS.md` 第 20 節「前端顯示的剩餘名額只能作為資訊」。

---

## C. 多堂報名交易規則

### 建議：☑ 全部成功或全部失敗（Atomic All-or-Nothing）

**原因**：

1. `AI_INSTRUCTIONS.md` 第 20 節明確禁止「前端讀名額 → 減 1 → 建報名」的不安全流程，要求交易/RPC 保護；all-or-nothing 是最直接滿足這個要求的設計，一個 RPC 呼叫、一個資料庫交易，邏輯單純、容易正確驗證。
2. 允許部分成功會需要「訂單裡每個項目各自有獨立狀態」的追蹤機制——這正是我們在 B 節刻意省略的 `order_items` 複雜度，為了 MVP 速度不值得現在做。
3. UX 更可預期：學生要嘛拿到「這 3 堂課都報名成功」的明確結果，要嘛拿到「哪一堂課失敗、原因是什麼」，可以調整後重新整批送出，不會卡在「部分報名成功、部分還要再處理一次」的中間狀態。
4. 代價：如果 3 堂課裡有 1 堂剛好滿了，學生要重新勾選再送出一次（多一步）。但目前是「確認需求量」階段，不是搶位高峰，這個代價很小；如果之後正式上線發現部分成功的需求很明確，可以在 P1 用「RPC 回傳每堂課個別結果」的方式漸進升級，不需要重新設計資料表。

### 資料庫如何保證一致性

單一 `SECURITY DEFINER` RPC `rpc_submit_full_term_registrations(p_class_ids uuid[], p_idempotency_key text)`，在**同一個資料庫交易**內完成：

```text
1. 檢查 idempotency_keys：若此 key 已 completed，直接回傳先前結果（不重複建立）
2. 寫入 idempotency_keys 一筆 status='processing'
3. 依 class_id 排序後，逐一對每個 class 執行 SELECT ... FOR UPDATE
   （固定排序是為了避免「兩位學生同時報名重疊班級組合、但勾選順序不同」造成 deadlock）
4. 對每個 class 檢查：
   - is_active = true AND is_open_for_registration = true
   - 該學生對此 class/term 沒有現存的 active 報名（防重複）
   - COUNT(active 期課報名) < classes.capacity（防超額）
   任何一項不通過 → 整個函式 RAISE EXCEPTION，帶回「哪些 class 失敗、原因」，
   交易自動整個 ROLLBACK，不會留下任何一筆報名
5. 全部通過才：依 venue_id 分組建立 orders（沿用 Phase 0 §11.3 已確認的多場地拆單規則），
   對每個 class 建立一筆 registrations，並寫入 audit_logs
6. idempotency_keys 標記 completed，回傳建立結果
```

### 名額競爭時如何避免超額

`SELECT ... FOR UPDATE` 鎖定每個涉及的 `class` 列，鎖定後才在同一交易內 `COUNT()` 現有有效報名數並與 `capacity` 比較，通過才 `INSERT`——這就是 `AI_INSTRUCTIONS.md` 第 8、20 節要求的標準模式，也是 Phase 0 §7 Concurrency Risk #1 已經定義好的機制，這裡只是把它套用在期課報名上。固定的鎖定順序（依 `class_id` 排序）避免多堂交錯報名時的 deadlock。

### RPC / Transaction 設計

如上方虛擬碼；實際 SQL 待你確認本計畫後，於 Phase 3/4 實作階段才建立對應 migration（本文件不建立任何 migration）。

### 前端收到結果後如何呈現

* **成功**：顯示「已成功報名：爵士舞初階、KPOP 舞蹈、女子舞蹈」確認頁，並可連到「我的報名」頁。
* **失敗**：顯示明確的逐項原因，例如「KPOP 舞蹈 已額滿，其餘 2 堂尚未送出，請調整後重新送出」。因為是 all-or-nothing，失敗時**不會**有任何一堂課被建立，學生可以直接取消勾選滿額的課、重新送出一次即可，不需要處理「已經報成功的部分」。

---

## D. 最短可上線路徑（P0 / P1 / P2）

### P0 — 學生開始報名前絕對必要

**資料庫**：
- `orders`、`registrations`（MVP 瘦身版）+ RLS + 防重複/防超額約束
- `fn_class_remaining_seats()`（唯讀名額顯示函式）
- `rpc_submit_full_term_registrations()`（原子報名 RPC）
- `handle_new_auth_user()` trigger（`auth.users` 新增時自動建立 `profiles`/`user_roles`）—— **待你先確認 A 節之前提到、我在上一輪發現的 `profiles.phone` NOT NULL 與 Admin Email 註冊衝突的解法**，這點沒解決 P0 就無法完整實作

**Authentication**：
- 學生 Phone+Password 註冊/登入（前端封鎖弱 PIN；後端 Auth Hook 強制封鎖延後到 P1）
- Admin Email+Password 登入
- Role 管理：自助註冊一律只拿 `student`，`admin` 一律手動指派（沿用 Phase 2 已定的 bootstrap 流程）

**學生前台頁面**：
- 註冊/登入頁
- 公開課程瀏覽頁（列出 `is_active AND is_open_for_registration` 的班級，顯示剩餘名額）
- 多選期課 + 送出報名頁
- 報名結果確認頁
- 我的報名（唯讀清單）

**管理功能**：
- Admin 登入
- 報名清單頁（唯讀，可依班級/期別篩選）
- 資料建立方式：SQL Seed Script 或 Supabase Studio 手動建立場地/期別/班級（不做 CRUD 表單）

**RLS / 權限**：
- `orders`/`registrations`：本人或 Admin 可 `SELECT`；無任何角色可直接 `INSERT`/`UPDATE`/`DELETE`（僅透過 RPC）
- 沿用 Phase 2 已驗收的 `is_admin()`、`profiles`/`user_roles` RLS

**測試（不可省略，對應 AI_INSTRUCTIONS §32 與 Phase 0 §8.3 高風險測試 #1、#8）**：
- Vitest：容量計算邏輯、電話正規化
- Supabase CLI：**多人同時搶最後一個期課名額**的併發測試（P0 最關鍵的一項，直接關係到會不會超賣）、Idempotency 重複送出測試、RLS（Student A 看不到 Student B 的報名/訂單）
- Playwright：登入 → 瀏覽 → 多選 → 送出 → 確認的 happy path e2e

> **完成以上這批工作後，真實學生就可以開始進行期課報名。**

### P1 — 可以在報名開始後繼續開發

- 弱 PIN 伺服器端強制封鎖（Auth Hook，待查證可行性）
- 登入失敗鎖定（`failed_login_count`/`locked_until` + 安全寫入路徑）
- SMS OTP（如果你屆時決定啟用）
- Admin 完整 CRUD（場地/期別/班級/課堂管理表單），取代 Seed Script
- 單堂報名（UI + RPC，資料庫已在 P0 預留）
- 付款狀態流程（`payments`、Admin 確認付款）
- 半期後停止整期報名的規則（目前用 Admin 手動關閉 `is_open_for_registration` 頂替，效果相同但需要人工操作）
- CSV 匯出（正式上線前必須完成，但不阻擋 P0 開放報名）
- 部分成功回報（如果實測後發現學生真的很需要「部分成功」而非整批重送）

### P2 — 後續功能

原 Roadmap Phase 6-13 其餘全部：優惠碼、運動中心學生資格、請假、補課、特別活動、席位轉讓、門禁、點名、Realtime、Admin MFA 強制、Production Testing 全面回歸。

---

## E. 預估工作量與風險

### 相對工作量（無法給出精確工時，以相對規模表示）

| 項目 | 相對規模 | 說明 |
|---|---|---|
| Auth 核心（signup/login/trigger/角色） | 中 | 主要工作在角色判斷邏輯與 `profiles.phone` nullable 的處理，UI 本身簡單 |
| `orders`/`registrations` schema + RLS | 小 | 沿用 Phase 2 已建立的模式，新增兩張表 |
| `rpc_submit_full_term_registrations` | 中大 | 核心邏輯所在，鎖定順序/併發測試需要仔細驗證，不能求快犧牲正確性 |
| 公開瀏覽頁 + 報名頁 + 我的報名 | 中 | 標準 CRUD 讀取頁面 + 一個多選送出表單 |
| Admin 登入 + 報名清單頁 | 小 | 唯讀頁面，不含管理表單 |
| Seed Script | 小 | 一次性 SQL，比做 CRUD 表單快很多 |
| 測試（併發/Idempotency/RLS/e2e） | 中 | 不可省略，但範圍已縮小到 MVP 路徑本身 |

### 最可能拖慢「開始報名」的風險

1. **`profiles.phone` NOT NULL 與 Admin Email 註冊的衝突**（上一輪已發現）：這個一定要先確認方案才能動工，否則 Auth Trigger 做出來會在 Admin 帳號建立時直接失敗。
2. **併發測試沒做足**：如果為了求快跳過「多人同時搶最後一個名額」的併發測試，一旦實際開放報名撞上超賣，後果比晚一兩天上線更嚴重（要處理已收到的錯誤報名、可能牽涉到你要跟教室確認的實際人數失真）。**建議不要砍這一項。**
3. **弱 PIN／登入鎖定被要求提前**：如果你之後改變主意、希望這些在 P0 就要有，會拉長 Auth 這塊的時間（尤其 Auth Hook 的可行性目前還沒查證完）。目前規劃是先不做，若你有疑慮請現在提出。
4. **Seed Script vs 手動要求 Admin CRUD**：如果你其實希望「開放報名當下」就能自己在後台新增/修改班級（而不是每次都要請我用 SQL 幫你建),就需要把部分 Admin CRUD 拉回 P0，這會直接增加工作量，請你評估一下開放報名初期，班級資料是否穩定（不太需要頻繁自行調整）。

### 如何避免不必要的功能拖延 MVP 上線

嚴格守住「P0 清單只做上面 D 節列出的項目」，任何新想法（即使很合理）先記錄到 P1/P2，不在報名開放前插隊實作——這也是延續整個專案至今「每個 Phase 結束才討論下一步」的紀律，只是把範圍改成以「報名可用」為單位，而不是原本的 Phase 編號。

---

## 待你確認的事項（確認後才會開始 Phase 3/4 實作）

1. **`profiles.phone` 改為 nullable + Trigger 角色判斷邏輯**（A/B 節提到的既有衝突）是否同意此解法？
2. **本 MVP 規劃的 P0/P1/P2 範圍劃分**是否同意？特別是「Admin 用 Seed Script 而非 CRUD 表單建班級」與「弱 PIN 封鎖/登入鎖定延後到 P1」這兩項，是否符合你的風險接受度？
3. **多堂報名採「全部成功或全部失敗」**是否同意？
4. 風險 E 節第 4 點：**開放報名初期，班級資料是否穩定**（決定 Admin CRUD 要不要拉回 P0）？

在你回覆以上四點之前，我不會開始下一個 Phase、不會修改現有資料庫 schema、不會建立新的 migration、也不會自行決定任何商業規則。

---

# End of REGISTRATION_MVP_PLAN.md
