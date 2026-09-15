<script setup lang="ts">
/**
 * AppShell — 全站共用版面與品牌導覽。
 *
 * 導覽列顯示與路由守衛只是 UX 層級的便利，不是安全邊界；
 * 真正的存取控制仍由 Supabase RLS 與角色權限在後端執行。
 */
import { RouterLink, useRoute } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const appName = import.meta.env.VITE_APP_NAME ?? 'Angel Zumba'
const route = useRoute()
const { isLoggedIn, isAdmin, user, logout } = useAuth()

function navigationClass(active: boolean) {
  return active ? 'font-semibold text-pink-600' : 'text-gray-700 transition hover:text-pink-600'
}

async function handleLogout() {
  await logout()
}
</script>

<template>
  <div class="flex min-h-screen flex-col">
    <header class="border-b border-gray-200 bg-white px-4 py-3">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-3">
        <RouterLink
          :to="{ name: 'home' }"
          class="shrink-0 text-lg font-semibold text-gray-900 transition hover:text-pink-600"
        >
          {{ appName }}
        </RouterLink>

        <nav
          aria-label="主要導覽"
          class="flex items-center justify-end gap-3 whitespace-nowrap text-xs sm:gap-4 sm:text-sm"
        >
          <RouterLink to="/courses" :class="navigationClass(route.name === 'courses')">
            <span class="sm:hidden">課程</span>
            <span class="hidden sm:inline">瀏覽課程</span>
          </RouterLink>

          <template v-if="isLoggedIn && !isAdmin">
            <RouterLink
              to="/my-registrations"
              :class="navigationClass(route.name === 'my-registrations')"
            >
              我的報名
            </RouterLink>

            <span class="hidden text-gray-400 sm:inline">{{ user?.phone }}</span>

            <button class="text-gray-700 transition hover:text-pink-600" @click="handleLogout">
              登出
            </button>
          </template>

          <template v-else-if="isLoggedIn && isAdmin">
            <RouterLink
              to="/admin/registrations"
              :class="navigationClass(route.name === 'admin-registrations')"
            >
              管理後台
            </RouterLink>

            <RouterLink
              to="/admin/students"
              :class="['hidden sm:inline', navigationClass(route.name === 'admin-students')]"
            >
              學生帳號
            </RouterLink>

            <RouterLink
              to="/admin/classes"
              :class="['hidden sm:inline', navigationClass(route.name === 'admin-classes')]"
            >
              期課
            </RouterLink>

            <RouterLink
              to="/admin/terms"
              :class="['hidden sm:inline', navigationClass(route.name === 'admin-terms')]"
            >
              期別
            </RouterLink>

            <RouterLink
              to="/admin/venues"
              :class="['hidden sm:inline', navigationClass(route.name === 'admin-venues')]"
            >
              場地
            </RouterLink>

            <button class="text-gray-700 transition hover:text-pink-600" @click="handleLogout">
              登出
            </button>
          </template>

          <template v-else>
            <RouterLink to="/login" :class="navigationClass(route.name === 'student-login')">
              <span class="sm:hidden">登入</span>
              <span class="hidden sm:inline">學生登入</span>
            </RouterLink>

            <RouterLink to="/register" :class="navigationClass(route.name === 'student-register')">
              <span class="sm:hidden">註冊</span>
              <span class="hidden sm:inline">學生註冊</span>
            </RouterLink>
          </template>
        </nav>
      </div>
    </header>

    <main class="flex-1 px-4 py-6 sm:py-8">
      <slot />
    </main>

    <footer class="border-t border-pink-100 bg-pink-50/40 px-4 py-7 text-center">
      <p class="text-base font-bold text-gray-800">{{ appName }}</p>
      <p class="mt-2 text-xs font-medium tracking-[0.16em] text-gray-500">SHINE. MOVE. SMILE.</p>
      <a
        href="https://www.instagram.com/angel.kao_zin/"
        target="_blank"
        rel="noopener noreferrer"
        class="mt-4 inline-flex min-h-11 items-center justify-center rounded-full bg-pink-600 px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-pink-700 focus:outline-none focus:ring-2 focus:ring-pink-400 focus:ring-offset-2"
        aria-label="在 Instagram 查看 Angel Zumba"
      >
        Instagram｜@angel.kao_zin
      </a>
    </footer>
  </div>
</template>
