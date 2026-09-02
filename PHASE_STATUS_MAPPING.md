# PHASE_STATUS_MAPPING.md

# Phase Roadmap 對照 Registration MVP（P0/P1/P2）狀態整理

> 本文件回應你的要求：往後固定區分兩個獨立維度——
> **Phase X = 專案開發階段**（`MASTER_SPEC.md` 第 44 節 / `PHASE_0_AUDIT_REPORT.md` 第 8.2 節定義的正式 Roadmap），
> **P0/P1/P2 = 功能優先級**（`REGISTRATION_MVP_PLAN.md` 定義，因報名優先的方向調整而產生的一次性重新排序）。
> 這兩者不是同一件事：P0 是「跨越了原本 Phase 3/4/5 的一個切片」，不等於「完成了 Phase 3」。以下逐項對照，不用「大致完成」這種模糊說法，每一項明確列出「做了/沒做」。

---

## 1. Phase 3（Authentication & Authorization）對照

依據 `PHASE_0_AUDIT_REPORT.md` 第 4.3 節逐項對照：

| Phase 3 原始項目 | 出處 | Registration MVP P0 狀態 |
|---|---|---|
| 學生 Phone+PIN 註冊/登入 | §4.3.1 第 1 點 | ✅ 已完成 |
| 電話號碼正規化（`normalizeTaiwanPhone`） | §4.3.1 第 2 點 | ✅ 已完成 |
| PIN 規則：6 位數、封鎖弱 PIN | §4.3.2 | 🟡 **只完成前端封鎖**，伺服器端強制（Auth Hook）**未完成** |
| 忘記 PIN：管理員協助重設流程（Edge Function） | §4.3.1 第 4 點 | ❌ **未完成，且目前不在任何 P1/P2 清單中——這是這次盤點發現的遺漏，見下方第 6 節** |
| 登入失敗鎖定（`failed_login_count`/`locked_until`） | §4.3.1 第 6 點 | ❌ 未完成（P1，`REGISTRATION_MVP_PLAN.md` 已列） |
| Rate Limiting（Supabase 專案層級設定） | §4.3.1 第 6 點 | ❌ 未設定/未驗證（屬於 Supabase Dashboard 設定，非程式碼） |
| CAPTCHA（註冊／連續登入失敗） | §4.3.1 第 7 點 | ❌ 未完成 |
| 首次手機簡訊驗證（OTP） | §4.3.1 第 3 點 | ❌ 未啟用（P1，待你決定是否啟用） |
| `auth.users` 新增時自動建立 `profiles`/`user_roles` 的 Trigger | §4.3.4 | ✅ 已完成 |
| 角色指派限制（不開放自助升級 admin） | §4.3.4 | ✅ 已完成 |
| 管理員 Email+Password 登入 | §4.3.3 | ✅ 已完成 |
| 管理員 MFA | §4.3.3 | ⏸ 依原計畫本來就排在「正式上線前的安全性複查」，不受本次調整影響，不算欠款 |
| RLS：`is_admin()` 輔助函式 | §4.3.5 | ✅ 已完成（Phase 2） |
| RLS：Owner-based 政策（含新增的 `orders`/`registrations`） | §4.3.5 | ✅ 已完成 |
| RLS：`door_access`／`coupons` 政策 | §4.3.5 | ⏸ 對應的資料表本身還不存在（Phase 11／Phase 6 範圍），不算 Phase 3 欠款 |

**結論：Phase 3 是「部分完成」，不是「完成」。** 完成的是「學生/管理員能登入、角色正確、基本 RLS 到位」這個最小子集；沒完成的是這次盤點前就存在、且與登入安全直接相關的多項強化（PIN 伺服器端強制、登入鎖定、忘記 PIN 流程、CAPTCHA、Rate Limit 設定）。

---

## 2. Phase 4（Admin Foundation）對照

依據 `MASTER_SPEC.md` 第 44 節 Phase 4 定義：

| Phase 4 原始項目 | Registration MVP P0 狀態 |
|---|---|
| Admin Layout | 🟡 只有最小骨架（登入守衛 + 導覽列一個「管理後台」連結），不是完整版面 |
| Dashboard（即時課程名額/今日課程/待確認付款/待審核補課/即將到期補課資格） | ❌ 未完成。**且其中多數子項（待確認付款、待審核補課、即將到期補課資格）依賴 Phase 6（付款）與 Phase 9（補課）尚未存在的資料，就算現在優先做，也做不出完整版本**——這不只是排序問題，是真正的資料依賴 |
| 場地（Venue）管理介面 | ❌ 未完成，以 `supabase/seed/registration_mvp_seed.sql` 頂替 |
| 期別（Term）管理介面 | ❌ 未完成，以 Seed Script 頂替 |
| 班級（Class）管理介面 | ❌ 未完成，以 Seed Script 頂替 |
| 課堂（Session）管理介面 | ❌ 未完成（`class_sessions` 表本身在 Phase 2 已建，但本輪完全沒有對應的管理 UI 或使用） |
| （新增，不在原 Phase 4 定義內）Admin 報名清單唯讀頁 | ✅ 已完成——**這其實是 Phase 5「報名」領域的管理端可見性，不是原本定義的 Phase 4 範疇**，只是剛好也在 Admin 區塊底下 |

**結論：Phase 4 幾乎沒有實質進展。** 唯一做的是「Admin 能登入、能看到一個頁面」的殼，真正的 Phase 4 內容（場地/期別/班級/課堂的管理表單、Dashboard）幾乎全部保留在 P1（Dashboard 的完整版本甚至要等到 Phase 6/9 的資料存在才有意義）。

---

## 3. Phase 5（Student Frontend & Registration）對照

依據 `MASTER_SPEC.md` 第 44 節 Phase 5 定義：

| Phase 5 原始項目 | Registration MVP P0 狀態 |
|---|---|
| Course Browsing | ✅ 已完成（含即時剩餘名額顯示） |
| Full-Term Registration | ✅ 已完成 |
| Multi-Class Registration（一次選多堂/多班） | ✅ 已完成（全部成功或全部失敗，含真實併發測試驗證） |
| Single-Session Registration | ❌ 未完成，資料庫已預留擴充能力（`registration_type`/`class_session_id`），P1 才做 UI/RPC |
| Orders（完整版：`order_items`＋定價彈性） | 🟡 **簡化版已完成**：`orders` 作為批次容器 + 伺服器端價格快照，但沒有 `order_items`（本輪判斷 MVP 只有期課一種商品型態，不需要）；等 P1 做單堂/特別活動時要重新評估是否需要補上 |

**結論：Phase 5 的「期課報名」核心已經完成，且是三個 Phase 中完成度最高的。** 缺的是 Single-Session（明確延後）與完整版 Orders（因為 MVP 範圍縮小而簡化，非疏漏）。

---

## 4. 正式 Roadmap 進度應該怎麼標記

**不建議把 Phase 3、Phase 4 或 Phase 5 標記為「✅ 完成」**——上面三節列出的具體缺項都是真的缺，不是文字遊戲。建議的標記方式：

```text
Phase 1  ✅ 完成並驗收
Phase 2  ✅ 完成並通過 Supabase Local Final Acceptance
Phase 3  🟡 部分完成（Registration MVP P0 範圍已完成；PIN 伺服器端強制／
             登入鎖定／忘記PIN流程／CAPTCHA／Rate Limit 設定 仍缺）
Phase 4  🟡 剛起步（僅 Admin 登入殼；場地/期別/班級管理介面、Dashboard 仍缺）
Phase 5  🟡 核心完成（期課瀏覽/整期/多堂報名已完成；單堂報名、完整版
             Orders 仍缺）
Phase 6-13  未開始（不受本次調整影響）
```

這個標記法同時保留了「你們已經能實際報名」這個重要進展，也誠實反映了 Phase 3/4 還有東西沒做，避免未來回頭看 Roadmap 時誤以為 Phase 3/4 已經全部驗收過。

---

## 5. 下一步該做「P1 功能」還是「原 Phase 3/4 尚未完成的必要工作」？

**這是同一件事，不是兩個互斥的選項。** 對照第 1-3 節可以看到，原本 Phase 3/4 尚未完成的項目，幾乎全部已經被 `REGISTRATION_MVP_PLAN.md` 收進 P1 清單：

* Phase 3 剩餘工作 → PIN 伺服器端強制、登入鎖定 → 已在 P1
* Phase 4 剩餘工作 → 場地/期別/班級 CRUD → 已在 P1
* Phase 5 剩餘工作 → 單堂報名 → 已在 P1

**例外（這次盤點新發現的落差，需要你確認怎麼處理）：**

1. **忘記 PIN 的管理員協助重設流程**（Phase 3 原始範圍，`PHASE_0_AUDIT_REPORT.md` §4.3.1 第 4 點）：目前**沒有出現在 P0 也沒有出現在 `REGISTRATION_MVP_PLAN.md` 的 P1/P2 清單裡**，是純粹的遺漏，不是刻意延後的決策。實務影響：現在如果有學生忘記 PIN，管理員完全沒有任何操作介面或後端流程可以幫快重設。建議補進 P1（甚至考慮要不要提前到 P0 追加，因為報名開放後確實會有學生忘記 PIN 的真實需求）——這點請你確認優先順序。
2. **CAPTCHA、Rate Limit 設定**：這兩項比較特殊，不是「寫程式碼」的工作，是 Supabase Dashboard 的設定，且與是否有真實流量濫用風險有關。建議列為 P1，但可以是「觀察報名開放後的實際狀況再決定是否需要」，不必然要在下一輪就做。
3. **Phase 4 Dashboard**：如上表所述，完整版本依賴 Phase 6/9 尚不存在的資料，就算排進 P1 也做不出完整版——真正能在 P1 做的只有「場地/期別/班級管理表單」，Dashboard 本身建議繼續留在原本的 Roadmap 位置（Phase 4 完整版，等相關資料都有了再做），不需要為了 P1 而做一個資料不全的半成品。

---

## 6. 往後的回報格式（避免再混淆）

從下一份報告開始，涉及「做了什麼」的地方，我會同時標示：

```text
[Phase 3 / P1] 登入失敗鎖定機制
[Phase 4 / P1] 場地管理表單
[Phase 5 / P1] 單堂報名
```

而不是只寫「P1 項目」或只寫「Phase 3 工作」。完成 P0 的下一步驗收後，這份文件也會跟著更新對照表，而不是被新的 Phase 報告取代。

---

# End of PHASE_STATUS_MAPPING.md
