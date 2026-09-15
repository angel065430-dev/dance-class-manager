import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'
import AppShell from '@/layouts/AppShell.vue'

function createTestRouter() {
  const page = { template: '<div />' }

  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'home', component: page },
      { path: '/courses', name: 'courses', component: page },
      { path: '/login', name: 'student-login', component: page },
      { path: '/register', name: 'student-register', component: page },
    ],
  })
}

describe('AppShell', () => {
  it('renders the default app name, footer branding, Instagram link and slot content', async () => {
    const router = createTestRouter()
    await router.push('/')
    await router.isReady()

    const wrapper = mount(AppShell, {
      global: { plugins: [router] },
      slots: {
        default: '<p>hello</p>',
      },
    })

    expect(wrapper.text()).toContain('Angel Zumba')
    expect(wrapper.text()).toContain('SHINE. MOVE. SMILE.')
    expect(wrapper.text()).toContain('@angel.kao_zin')
    expect(wrapper.html()).toContain('hello')

    const instagramLink = wrapper.get('a[href="https://www.instagram.com/angel.kao_zin/"]')

    expect(instagramLink.attributes('target')).toBe('_blank')
    expect(instagramLink.attributes('rel')).toContain('noopener')
  })

  it('highlights the current public navigation item', async () => {
    const router = createTestRouter()
    await router.push('/courses')
    await router.isReady()

    const wrapper = mount(AppShell, {
      global: { plugins: [router] },
    })

    const courseLink = wrapper.get('a[href="/courses"]')

    expect(courseLink.classes()).toContain('text-pink-600')
    expect(courseLink.classes()).toContain('font-semibold')
  })
})
