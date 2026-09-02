/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Supabase 專案 URL（公開，可放前端） */
  readonly VITE_SUPABASE_URL: string
  /** Supabase anon public key（公開，可放前端；絕不可放 service role key） */
  readonly VITE_SUPABASE_ANON_KEY: string
  /** 系統顯示名稱（品牌設定的前端預設值，正式品牌設定仍以資料庫為準，見 MASTER_SPEC.md 第 32 節） */
  readonly VITE_APP_NAME?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
