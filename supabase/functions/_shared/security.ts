export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export function normalizeTaiwanPhone(raw: unknown): string | null {
  if (typeof raw !== 'string') return null
  const value = raw.replace(/[\s-]/g, '')
  if (/^\+8869\d{8}$/.test(value)) return value
  if (/^8869\d{8}$/.test(value)) return `+${value}`
  if (/^09\d{8}$/.test(value)) return `+886${value.slice(1)}`
  return null
}

export function isStrongPin(pin: unknown): pin is string {
  if (typeof pin !== 'string' || !/^\d{6}$/.test(pin)) return false
  if (/^(\d)\1{5}$/.test(pin)) return false
  const digits = [...pin].map(Number)
  const ascending = digits.every((digit, index) => index === 0 || digit === digits[index - 1] + 1)
  const descending = digits.every((digit, index) => index === 0 || digit === digits[index - 1] - 1)
  return !ascending && !descending
}

export function generateStrongPin(): string {
  const values = new Uint32Array(1)
  do {
    crypto.getRandomValues(values)
    const pin = String(values[0] % 1_000_000).padStart(6, '0')
    if (isStrongPin(pin)) return pin
  } while (true)
}

export async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

export function normalizeInvitationCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null
  const value = raw.replace(/[\s-]/g, '').toUpperCase()
  return /^[A-Z2-9]{12}$/.test(value) ? value : null
}

export function generateInvitationCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const bytes = new Uint8Array(12)
  crypto.getRandomValues(bytes)
  return [...bytes].map((value) => alphabet[value % alphabet.length]).join('')
}

/** Supabase 無 SMS provider 時的內部 Auth identifier；不會顯示給使用者或寄信。 */
export async function internalStudentEmail(phone: string) {
  return `student.${await sha256Hex(phone)}@auth.angelzumba.invalid`
}
