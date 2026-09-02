import { describe, it, expect } from 'vitest'
import { normalizeTaiwanPhone } from '@/utils/phone'

describe('normalizeTaiwanPhone', () => {
  it('accepts standard 09-prefixed local format', () => {
    const result = normalizeTaiwanPhone('0912345678')
    expect(result).toEqual({ ok: true, e164: '+886912345678' })
  })

  it('accepts already-normalized E.164 format', () => {
    const result = normalizeTaiwanPhone('+886912345678')
    expect(result).toEqual({ ok: true, e164: '+886912345678' })
  })

  it('accepts country code without leading +', () => {
    const result = normalizeTaiwanPhone('886912345678')
    expect(result).toEqual({ ok: true, e164: '+886912345678' })
  })

  it('strips spaces and dashes before validating', () => {
    const result = normalizeTaiwanPhone('0912-345-678')
    expect(result).toEqual({ ok: true, e164: '+886912345678' })
  })

  it('rejects landline-shaped numbers', () => {
    const result = normalizeTaiwanPhone('0223456789')
    expect(result.ok).toBe(false)
  })

  it('rejects too-short input', () => {
    const result = normalizeTaiwanPhone('09123')
    expect(result.ok).toBe(false)
  })

  it('rejects empty input', () => {
    const result = normalizeTaiwanPhone('')
    expect(result.ok).toBe(false)
  })
})
