/**
 * PIN（學生登入密碼）前端封鎖規則。
 *
 * 對應 PHASE_0_AUDIT_REPORT.md 第 4.3.2 節：6 位數字，禁止全部相同數字、
 * 連續遞增／遞減。
 *
 * 此規則也在帳號建立與管理員重設 PIN 的 Edge Function 強制執行；這份前端
 * 實作只負責讓使用者提早看到可理解的錯誤訊息。
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
