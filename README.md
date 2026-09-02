# 舞蹈課程管理系統（Dance Class Manager）

多使用者的舞蹈課程報名／請假／補課管理系統。學生前台、學生專區、老師／管理員後台共用同一個 Supabase 中央資料庫，不使用 LocalStorage 作為正式業務資料來源。

> 本專案的需求與開發規則以下列文件為準，衝突時依此優先順序判斷：
>
> 1. `MASTER_SPEC.md` — 產品需求規格（含第 49 節 Phase 0 Confirmed Decisions Addendum）
> 2. `AI_INSTRUCTIONS.md` — AI 開發規則
> 3. `PHASE_0_AUDIT_REPORT.md` — Phase 0 專案稽核與架構規劃報告（含資料庫 Schema 草案、Authentication 方案、Concurrency 設計）
>
> 開發任何功能前，請先讀過這三份文件，不要根據舊程式碼或舊 Prompt 自行恢復已淘汰的需求。

**目前進度：Phase 1 — Project Foundation。** 本專案採分階段開發（見 `PHASE_0_AUDIT_REPORT.md` 第 8 節 Roadmap），每個 Phase 完成後會停下來等待確認，不會自動跳到下一個 Phase。

## 技術棧

- Vue 3（Composition API）+ TypeScript
- Vite
- Tailwind CSS 4
- Vue Router
- Supabase（PostgreSQL + Auth + Realtime）
- Vitest + @vue/test-utils（單元測試）
- Playwright（e2e 測試）
- ESLint（flat config）+ Prettier

## 開始使用

### 1. 安裝依賴

```bash
npm install
```

> **重要**：本專案的檔案是在沒有一般網際網路存取權限的雲端沙盒環境中建立的（無法連線 npm registry），因此 `node_modules/` 與 `package-lock.json` 都**尚未**產生，也還沒有實際執行過 `npm install`／`npm run build`／`npm run lint`／`npm run test:unit`。請在你自己的電腦上（有正常網路連線）執行 `npm install`，第一次安裝時 npm 會依 `package.json` 中的版本範圍解析出實際版本並產生 `package-lock.json`。詳見本檔案最下方「已知限制」。

### 2. 設定環境變數

```bash
cp .env.example .env.local
```

編輯 `.env.local`，填入你的 Supabase 專案資訊（`VITE_SUPABASE_URL`、`VITE_SUPABASE_ANON_KEY`，在 Supabase Dashboard 的 Project Settings → API 取得）。

> 絕對不要把 `SUPABASE_SERVICE_ROLE_KEY` 或任何管理密鑰放進 `.env.local` 或任何 `VITE_` 開頭的變數 — 這些變數會被打包進前端程式碼，任何人都看得到。

### 3. 啟動開發伺服器

```bash
npm run dev
```

### 4. 其他常用指令

| 指令                       | 用途                                                   |
| -------------------------- | ------------------------------------------------------ |
| `npm run build`            | 型別檢查（`vue-tsc`）+ 正式建置                        |
| `npm run type-check`       | 只跑型別檢查                                           |
| `npm run lint`             | ESLint 檢查並自動修正                                  |
| `npm run format`           | Prettier 格式化 `src/`                                 |
| `npm run test:unit`        | 執行 Vitest 單元測試                                   |
| `npm run test:unit:watch`  | Vitest watch 模式                                      |
| `npm run test:e2e:install` | 安裝 Playwright 瀏覽器（第一次跑 e2e 前需要）          |
| `npm run test:e2e`         | 執行 Playwright e2e 測試（會先啟動 `npm run preview`） |

## 目錄結構

```text
.
├── .github/workflows/ci.yml   # CI：type-check / lint / format / unit test / build
├── e2e/                       # Playwright e2e 測試
├── public/                    # 靜態資源
├── src/
│   ├── assets/main.css        # 全域樣式（Tailwind 進入點）
│   ├── layouts/AppShell.vue   # 最基礎版面骨架（Phase 1，不含業務邏輯）
│   ├── lib/supabaseClient.ts  # Supabase client 單例（僅 anon key）
│   ├── pages/                 # 頁面元件（Phase 1 僅有佔位首頁與 404）
│   ├── router/index.ts        # Vue Router（Phase 1 僅註冊首頁/404）
│   ├── App.vue
│   └── main.ts
├── supabase/config.toml       # Supabase CLI 本機開發設定（不含 migrations）
├── tests/unit/                # Vitest 單元測試
├── .env.example                # 環境變數範例
├── eslint.config.js
├── playwright.config.ts
├── tailwind 設定已內建於 vite.config.ts（Tailwind CSS 4 的 @tailwindcss/vite 插件方式，不需要 tailwind.config.js）
├── tsconfig*.json
├── vite.config.ts
└── vitest.config.ts
```

> Phase 1 刻意**不**包含：任何資料表／migration／RLS policy／正式 Auth 功能／報名／請假／補課／付款功能／業務 RPC。這些依規劃屬於 Phase 2 之後的範圍，請見 `PHASE_0_AUDIT_REPORT.md` 第 8.2 節 Phase 清單。

## 已知限制（Phase 1 完成報告的一部分，另見對話中的完整報告）

本專案的檔案是在 Claude 的雲端沙盒工作環境中建立的，該環境的網路存取權限經確認**不允許連線 `registry.npmjs.org`、內部 artifactory 鏡像、或任何公開 CDN**（`curl`/`npm` 皆回傳 `403 host_not_allowed`）。因此：

- 無法在該環境中執行 `npm install`，`node_modules/` 與 `package-lock.json` 未產生。
- 無法實際執行 `npm run build`（`vue-tsc` + `vite build`）、`npm run lint:check`（完整的 Vue+TS ESLint 規則需要安裝 `eslint-plugin-vue` 等套件）、`npm run test:unit`（`vitest` 尚未安裝）、`npm run test:e2e`（`playwright` 套件與瀏覽器尚未安裝）。
- 所有設定檔／原始碼是依照 Vue 官方 `create-vue` 鷹架的標準慣例手動撰寫，並以 Prettier（本機已預裝、與套件安裝無關）驗證過格式；但**尚未經過實際的 TypeScript 編譯器與 ESLint 規則驗證**。

**請在你自己的電腦上完成第一次真正的驗證**：

```bash
npm install
npm run type-check
npm run lint:check
npm run format:check
npm run test:unit
npm run build
```

若上述任何一步出錯，請將錯誤訊息回報，我會在下一輪修正。這點會在 Phase 1 完成報告中列為「發現的問題」而非隱藏不提。
