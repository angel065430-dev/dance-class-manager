import { describe, expect, it } from 'vitest'
import { normalizeStudentName, normalizeLineDisplayName, studentDisplayName } from '@/utils/studentNames'

describe('student names', () => {
  it('requires a legal name without excluding uncommon legal names', () => {
    expect(normalizeStudentName('  陳 小美  ')).toBe('陳 小美')
    expect(normalizeStudentName('May Chen')).toBe('May Chen')
    expect(() => normalizeStudentName('')).toThrow()
    expect(() => normalizeStudentName('a'.repeat(81))).toThrow()
    expect(() => normalizeStudentName(123)).toThrow()
  })
  it('accepts optional LINE display names', () => {
    expect(normalizeLineDisplayName(' May ')).toBe('May')
    expect(normalizeLineDisplayName('')).toBeNull()
    expect(normalizeLineDisplayName(null)).toBeNull()
    expect(studentDisplayName('陳小美', 'May')).toBe('陳小美（May）')
  })
  it('rejects invalid types, controls and excessive length', () => {
    expect(() => normalizeLineDisplayName(123)).toThrow()
    expect(() => normalizeLineDisplayName('a\u0000b')).toThrow()
    expect(() => normalizeLineDisplayName('a'.repeat(101))).toThrow()
  })
})
