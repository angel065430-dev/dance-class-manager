import { describe, it, expect } from 'vitest'
import { validatePin } from '@/utils/pin'

describe('validatePin', () => {
  it('accepts a reasonable 6-digit PIN', () => {
    expect(validatePin('284915')).toEqual({ ok: true })
  })

  it('rejects non-6-digit input', () => {
    expect(validatePin('12345').ok).toBe(false)
    expect(validatePin('1234567').ok).toBe(false)
    expect(validatePin('12a456').ok).toBe(false)
  })

  it('rejects all-same-digit PINs', () => {
    expect(validatePin('000000').ok).toBe(false)
    expect(validatePin('999999').ok).toBe(false)
  })

  it('rejects ascending sequential PINs', () => {
    expect(validatePin('123456').ok).toBe(false)
    expect(validatePin('012345').ok).toBe(false)
  })

  it('rejects descending sequential PINs', () => {
    expect(validatePin('654321').ok).toBe(false)
    expect(validatePin('987654').ok).toBe(false)
  })

  it('accepts a PIN that merely contains a short run but is not fully sequential', () => {
    expect(validatePin('123987').ok).toBe(true)
  })
})
