import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createWebHistory } from 'vue-router'
import AppShell from '@/layouts/AppShell.vue'

/**
 * AppShell 現在會用到 RouterLink 與 useAuth()（Registration MVP，P0），
 * 所以測試需要安裝一個最小的測試用 router，而不是像 Phase 1 時那樣單獨掛載。
 * useAuth() 內部建立 Supabase client 屬於延遲連線（建構時不會發送任何網路
 * 請求），在沒有設定 VITE_SUPABASE_URL 的測試環境下仍可安全掛載。
 */
describe('AppShell', () => {
  it('renders the default app name and slot content', async () => {
    const router = createRouter({
      history: createWebHistory(),
      routes: [{ path: '/', name: 'home', component: { template: '<div />' } }],
    })
    router.push('/')
    await router.isReady()

    const wrapper = mount(AppShell, {
      global: { plugins: [router] },
      slots: {
        default: '<p>hello</p>',
      },
    })

    expect(wrapper.text()).toContain('舞蹈課程管理系統')
    expect(wrapper.html()).toContain('hello')
  })
})
