/**
 * PIN（學生登入密碼）前端封鎖規則。
 *
 * 對應 PHASE_0_AUDIT_REPORT.md 第 4.3.2 節：6 位數字，禁止全部相同數字、
 * 連續遞增／遞減。
 *
 * 重要說明（REGISTRATION_MVP_PLAN.md「明確延後的項目」）：這裡只是前端層級
 * 的第一道防線，方便使用者及早得到錯誤訊息，*不構成*規格要求的「不可只在
 * 前端擋」的伺服器端強制。真正的伺服器端強制（透過 Supabase Auth Hook 或等
 * 效機制）已列入 P1，尚未實作；目前的殘餘風險已在 MVP Plan 中向使用者說明
 * 並取得確認（金流本來就是人工核對付款，冒用手機號碼無法直接造成金錢損失）。
 */

export type PinValidationResult = { ok: true } | { ok: false; error: string }

const ALL_SAME_DIGIT = /^(\d)\1{5}$/

function isSequential(pin: string): boolean {
  const digits = pin.split('').map(Number)
  let ascending = true
  let descending = true
  for (let i = 1; i < digits.length; i++) {
    if (digits[i] !== digits[i - 1] + 1) ascending = false
    if (digits[i] !== digits[i - 1] - 1) descending = false
  }
  return ascending || descending
}

export function validatePin(pin: string): PinValidationResult {
  if (!/^\d{6}$/.test(pin)) {
    return { ok: false, error: 'PIN 必須是 6 位數字' }
  }
  if (ALL_SAME_DIGIT.test(pin)) {
    return { ok: false, error: 'PIN 不可以是全部相同的數字（例如 111111）' }
  }
  if (isSequential(pin)) {
    return { ok: false, error: 'PIN 不可以是連續遞增或遞減的數字（例如 123456、654321）' }
  }
  return { ok: true }
}
