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

  it('supports redirect, pending cancellation, seat release, repricing and admin cancellation', () => {
    const sql = readFileSync('supabase/migrations/20260910040023_pending_registration_cancellation.sql', 'utf8')
    const courses = readFileSync('src/pages/student/CoursesView.vue', 'utf8')
    const mine = readFileSync('src/pages/student/MyRegistrationsView.vue', 'utf8')
    const admin = readFileSync('src/pages/admin/AdminRegistrationsView.vue', 'utf8')

    expect(courses).toContain("name: 'my-registrations'")
    expect(courses).toContain("registered: '1'")
    expect(mine).toContain('✅ 報名成功！名額已為你保留。')
    expect(mine).toContain('cancelMyPendingRegistration')
    expect(admin).toContain('adminCancelPendingRegistration')
    expect(sql).toContain('rpc_cancel_my_pending_registration')
    expect(sql).toContain('rpc_admin_cancel_pending_registration')
    expect(sql).toContain("status = 'cancelled'")
    expect(sql).toContain('fn_recalculate_order_amount')
    expect(sql).toContain('full_term_discount_percent')
    expect(sql).toContain('v_discount_percent / 100.0')
    expect(sql).toContain('v_order.payment_method IS NOT NULL OR v_order.payment_reference IS NOT NULL')
  })
})
