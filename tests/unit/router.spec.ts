import { describe, it, expect } from 'vitest'
import router from '@/router'

describe('router', () => {
  it('resolves the home route', () => {
    const resolved = router.resolve('/')
    expect(resolved.name).toBe('home')
  })

  it('falls back to not-found for unknown paths', () => {
    const resolved = router.resolve('/this-route-does-not-exist')
    expect(resolved.name).toBe('not-found')
  })

  it('resolves the Registration MVP student/admin routes', () => {
    expect(router.resolve('/login').name).toBe('student-login')
    expect(router.resolve('/register').name).toBe('student-register')
    expect(router.resolve('/courses').name).toBe('courses')
    expect(router.resolve('/my-registrations').name).toBe('my-registrations')
    expect(router.resolve('/admin/login').name).toBe('admin-login')
    expect(router.resolve('/admin/registrations').name).toBe('admin-registrations')
  })
})
