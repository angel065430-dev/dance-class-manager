import { createClient } from '@supabase/supabase-js'

/**
 * Supabase Client 單例。
 *
 * 安全規則（MASTER_SPEC.md 第 42 節 / AI_INSTRUCTIONS.md 第 11、30 節，禁止事項）：
 *   - 這裡只能使用 VITE_SUPABASE_URL 與 VITE_SUPABASE_ANON_KEY（anon public key）。
 *   - 絕對不可以在任何前端程式碼中出現 SUPABASE_SERVICE_ROLE_KEY 或其他機密。
 *   - 所有需要 Service Role 權限的操作（例如管理員重設學生 PIN），
 *     一律透過後端 Edge Function 處理，前端只呼叫該 Function 的 HTTPS 端點。
 *
 * Phase 1 階段本檔案只建立與匯出 client 本身，不包含任何登入/註冊/資料查詢邏輯——
 * 那些屬於 Phase 3 起才會實作的範圍。
 */

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  // 在開發階段盡早失敗，避免帶著空設定跑起來卻在深層呼叫才報錯。
  // 正式環境（Vercel）請在專案的環境變數設定中提供這兩個值。
  console.warn(
    '[supabaseClient] 尚未設定 VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY，' +
      '請複製 .env.example 為 .env.local 並填入你的 Supabase 專案資訊。',
  )
}

export const supabase = createClient(supabaseUrl ?? '', supabaseAnonKey ?? '')
