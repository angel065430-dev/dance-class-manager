import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

describe('prelaunch registration contract', () => {
  it('keeps registration discount server-side and defaults to 2+ classes at 96 percent', () => {
    const sql = readFileSync('supabase/migrations/20260910030022_registration_discount_settings.sql', 'utf8')
    expect(sql).toContain('DEFAULT 2')
    expect(sql).toContain('DEFAULT 96.00')
    expect(sql).toContain('selected_term_counts')
    expect(sql).toContain('full_term_discount_percent / 100.0')
    expect(sql).toContain('subtotal_amount = t.subtotal, total_amount = t.total')
  })

  it('removes invitation code from public registration and account creation', () => {
    const view = readFileSync('src/pages/student/RegisterView.vue', 'utf8')
    const fn = readFileSync('supabase/functions/create-student-account/index.ts', 'utf8')
    expect(view).not.toContain('invitation-code')
    expect(view).not.toContain('安全邀請碼')
    expect(fn).not.toContain('claim_student_invitation')
    expect(fn).not.toContain('invitation_code')
    expect(fn).toContain('consume_student_signup_attempt')
  })
})
