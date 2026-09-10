import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('student name integration contract', () => {
  it('validates names before consuming an invitation or creating an Auth user', () => {
    const source = readFileSync('supabase/functions/create-student-account/index.ts', 'utf8')
    expect(source.indexOf('normalizeStudentName(body.name)')).toBeGreaterThan(-1)
    expect(source.indexOf('normalizeStudentName(body.name)')).toBeLessThan(source.indexOf("consume_student_signup_attempt"))
    expect(source.indexOf('normalizeStudentName(body.name)')).toBeLessThan(source.indexOf('claim_student_invitation'))
    expect(source).toContain('line_display_name: lineDisplayName')
    expect(source).toContain('updatedProfiles?.length !== 1')
  })
  it('keeps identity and existing profile rows unchanged in the migration', () => {
    const sql = readFileSync('supabase/migrations/20260910010020_student_names.sql', 'utf8')
    expect(sql).toContain('ADD COLUMN IF NOT EXISTS line_display_name')
    expect(sql).not.toMatch(/\b(?:DROP TABLE|TRUNCATE|DELETE FROM|UPDATE public\.profiles)\b/i)
  })
})
