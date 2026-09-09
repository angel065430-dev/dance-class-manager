import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { isStrongPin, normalizeInvitationCode } from '../../supabase/functions/_shared/security'

describe('student auth security helpers', () => {
  it('normalizes only 12-character non-ambiguous invitation codes', () => {
    expect(normalizeInvitationCode('abcd-2345-efgh')).toBe('ABCD2345EFGH')
    expect(normalizeInvitationCode('ABCD1234EFGH')).toBeNull()
    expect(normalizeInvitationCode('too-short')).toBeNull()
  })

  it('keeps PIN validation server-side', () => {
    expect(isStrongPin('284915')).toBe(true)
    expect(isStrongPin('111111')).toBe(false)
    expect(isStrongPin('123456')).toBe(false)
  })
})

describe('student auth security boundaries', () => {
  it('uses atomic database RPCs and row locks for throttling', () => {
    const migration = readFileSync('supabase/migrations/20260909010017_harden_student_auth.sql', 'utf8')
    expect(migration).toContain('FOR UPDATE')
    expect(migration).toContain('reserve_student_login_attempt')
    expect(migration).toContain('consume_student_signup_attempt')
    expect(migration).toContain('REVOKE ALL ON FUNCTION')
  })

  it('fails closed in login code instead of read-modify-write throttling', () => {
    const login = readFileSync('supabase/functions/student-pin-login/index.ts', 'utf8')
    expect(login).toContain("rpc('reserve_student_login_attempt'")
    expect(login).toContain("rpc('clear_student_login_failures'")
    expect(login).not.toMatch(/from\(['"]student_auth_throttles['"]\)\.select/)
    expect(login).toContain("signOut({ scope: 'global' })")
  })

  it('does not expose service role or persist PINs in frontend source', () => {
    const frontend = [
      readFileSync('src/composables/useAuth.ts', 'utf8'),
      readFileSync('src/services/studentAccounts.ts', 'utf8'),
      readFileSync('src/lib/supabaseClient.ts', 'utf8'),
    ].join('\n')
    expect(frontend).not.toMatch(/VITE_.*SERVICE_ROLE/)
    expect(frontend).not.toMatch(/profiles["'`]?\s*\.\s*(insert|update).*pin/is)
  })

  it('routes post-registration login through student-pin-login', () => {
    const source = readFileSync('src/composables/useAuth.ts', 'utf8')
    const signUpBody = source.slice(source.indexOf('async function signUpStudent'), source.indexOf('async function loginStudent'))
    expect(signUpBody).toContain('return loginStudent')
    expect(signUpBody).not.toContain('signInWithPassword')
  })
})
