/**
 * 台灣手機號碼正規化工具。
 *
 * 對應 PHASE_0_AUDIT_REPORT.md 第 4.3.1 節第 2 點：Supabase Phone Auth 要求
 * E.164 格式（例：+886912345678），但台灣使用者慣用輸入 0912345678。
 * 必須統一在註冊、登入、忘記密碼、管理員後台查詢學生等所有入口使用同一套
 * 正規化規則，避免「同一號碼因格式不同被系統誤判為兩個帳號」。
 *
 * 只接受台灣手機門號（09 開頭，共 10 碼），市話與其他國家號碼不在本系統
 * 登入功能的範圍內。
 */

export type PhoneNormalizeResult = { ok: true; e164: string } | { ok: false; error: string }

const TW_LOCAL_MOBILE = /^09\d{8}$/
const TW_E164_MOBILE = /^\+8869\d{8}$/
const TW_BARE_COUNTRY_CODE_MOBILE = /^8869\d{8}$/

export function normalizeTaiwanPhone(raw: string): PhoneNormalizeResult {
  const trimmed = (raw ?? '').replace(/[\s-]/g, '')

  if (TW_E164_MOBILE.test(trimmed)) {
    return { ok: true, e164: trimmed }
  }
  if (TW_BARE_COUNTRY_CODE_MOBILE.test(trimmed)) {
    return { ok: true, e164: `+${trimmed}` }
  }
  if (TW_LOCAL_MOBILE.test(trimmed)) {
    return { ok: true, e164: `+886${trimmed.slice(1)}` }
  }

  return {
    ok: false,
    error: '請輸入正確的台灣手機號碼（例如 0912345678）',
  }
}
