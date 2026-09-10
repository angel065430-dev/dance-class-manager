import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import AdminStudentsView from '@/pages/admin/AdminStudentsView.vue'

const listMock = vi.fn()
vi.mock('@/services/adminStudentProfiles', () => ({
  fetchAdminStudentProfiles: (...args: unknown[]) => listMock(...args),
}))
const resetMock = vi.fn()
vi.mock('@/services/studentAccounts', () => ({
  adminResetStudentPin: (...args: unknown[]) => resetMock(...args),
}))

describe('AdminStudentsView', () => {
  beforeEach(() => { listMock.mockReset(); listMock.mockResolvedValue([]); resetMock.mockReset(); vi.spyOn(window, 'confirm').mockReturnValue(true) })

  it('searches students by LINE name and displays the stable ID', async () => {
    listMock.mockResolvedValue([
      { id: 'student-1', name: '陳小美', line_display_name: 'May', phone: '+886912345678', created_at: '2026-09-10T00:00:00Z' },
      { id: 'student-2', name: '王大明', line_display_name: null, phone: '+886987654321', created_at: '2026-09-10T00:00:00Z' },
    ])
    const wrapper = mount(AdminStudentsView)
    await vi.waitFor(() => expect(wrapper.text()).toContain('陳小美（May）'))
    await wrapper.get('input[type="search"]').setValue('May')
    expect(wrapper.text()).not.toContain('王大明')
    const studentButton = wrapper.findAll('button').find(b => b.text().includes('陳小美'))
    expect(studentButton).toBeDefined()
    await studentButton!.trigger('click')
    expect(wrapper.text()).toContain('student-1')
  })


  it('displays the returned PIN once and can clear it', async () => {
    resetMock.mockResolvedValue({ pin: '284915' })
    const wrapper = mount(AdminStudentsView)
    await wrapper.get('#student-phone').setValue('0912345678')
    await wrapper.get('#reset-reason').setValue('學生現場核對身分')
    await wrapper.get('form').trigger('submit')
    await vi.waitFor(() => expect(wrapper.text()).toContain('284915'))
    await wrapper.get('button[type="button"]').trigger('click')
    expect(wrapper.text()).not.toContain('284915')
  })
})
