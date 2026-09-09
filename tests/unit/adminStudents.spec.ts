import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import AdminStudentsView from '@/pages/admin/AdminStudentsView.vue'

const resetMock = vi.fn()
const inviteMock = vi.fn()
vi.mock('@/services/studentAccounts', () => ({
  adminResetStudentPin: (...args: unknown[]) => resetMock(...args),
  adminCreateStudentInvitation: (...args: unknown[]) => inviteMock(...args),
}))

describe('AdminStudentsView', () => {
  beforeEach(() => { resetMock.mockReset(); inviteMock.mockReset(); vi.spyOn(window, 'confirm').mockReturnValue(true) })

  it('creates and displays a phone-bound invitation once', async () => {
    inviteMock.mockResolvedValue({ code: 'ABCD2345EFGH', expiresAt: '2026-09-12T00:00:00.000Z' })
    const wrapper = mount(AdminStudentsView)
    await wrapper.get('#invite-phone').setValue('0912345678')
    await wrapper.get('form').trigger('submit')
    await vi.waitFor(() => expect(wrapper.text()).toContain('ABCD2345EFGH'))
    expect(inviteMock).toHaveBeenCalledWith('0912345678', '')
  })

  it('displays the returned PIN once and can clear it', async () => {
    resetMock.mockResolvedValue({ pin: '284915' })
    const wrapper = mount(AdminStudentsView)
    await wrapper.get('#student-phone').setValue('0912345678')
    await wrapper.get('#reset-reason').setValue('學生現場核對身分')
    await wrapper.findAll('form')[1].trigger('submit')
    await vi.waitFor(() => expect(wrapper.text()).toContain('284915'))
    await wrapper.get('button[type="button"]').trigger('click')
    expect(wrapper.text()).not.toContain('284915')
  })
})
