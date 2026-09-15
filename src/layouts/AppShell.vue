<script setup lang="ts">
/**
 * AppShell — 全站共用版面。
 *
 * Registration MVP（P0）範圍：只提供最基本的導覽（首頁／課程瀏覽／我的報名／
 * 登入登出），不含完整品牌設定（Logo、Hero、公告等，MASTER_SPEC.md 第 32
 * 節，留待 P1 之後的 Admin Foundation 完整實作）。
 *
 * 導覽列的顯示/隱藏只是 UX 層級的方便性，不是安全邊界；真正的存取控制
 * 一律由 Supabase RLS + Role 在後端強制執行（AI_INSTRUCTIONS.md 第 10-11
 * 節）。
 */
import { RouterLink } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const appName = import.meta.env.VITE_APP_NAME ?? 'Angel Zumba'
const { isLoggedIn, isAdmin, user, logout } = useAuth()

async function handleLogout() {
  await logout()
}
</script>

<template>
  <div class="flex min-h-screen flex-col">
    <header class="border-b border-gray-200 bg-white px-4 py-3">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-3">
        <RouterLink :to="{ name: 'home' }" class="shrink-0 text-lg font-semibold text-gray-900">{{
          appName
        }}</RouterLink>

        <nav
          class="flex items-center justify-end gap-3 whitespace-nowrap text-xs sm:gap-4 sm:text-sm"
        >
          <RouterLink to="/courses" class="text-gray-700 hover:text-gray-900">
            <span class="sm:hidden">課程</span>
            <span class="hidden sm:inline">瀏覽課程</span>
          </RouterLink>

          <template v-if="isLoggedIn && !isAdmin">
            <RouterLink to="/my-registrations" class="text-gray-700 hover:text-gray-900"
              >我的報名</RouterLink
            >
            <span class="hidden text-gray-400 sm:inline">{{ user?.phone }}</span>
            <button class="text-gray-700 hover:text-gray-900" @click="handleLogout">登出</button>
          </template>

          <template v-else-if="isLoggedIn && isAdmin">
            <RouterLink to="/admin/registrations" class="text-gray-700 hover:text-gray-900"
              >管理後台</RouterLink
            >
            <RouterLink
              to="/admin/students"
              class="hidden text-gray-700 hover:text-gray-900 sm:inline"
              >學生帳號</RouterLink
            >
            <RouterLink
              to="/admin/classes"
              class="hidden text-gray-700 hover:text-gray-900 sm:inline"
              >期課</RouterLink
            >
            <RouterLink to="/admin/terms" class="hidden text-gray-700 hover:text-gray-900 sm:inline"
              >期別</RouterLink
            >
            <RouterLink
              to="/admin/venues"
              class="hidden text-gray-700 hover:text-gray-900 sm:inline"
              >場地</RouterLink
            >
            <button class="text-gray-700 hover:text-gray-900" @click="handleLogout">登出</button>
          </template>

          <template v-else>
            <RouterLink to="/login" class="text-gray-700 hover:text-gray-900">
              <span class="sm:hidden">登入</span>
              <span class="hidden sm:inline">學生登入</span>
            </RouterLink>
            <RouterLink to="/register" class="text-gray-700 hover:text-gray-900">
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

    <footer class="border-t border-gray-200 px-4 py-3 text-center text-xs text-gray-400">
      {{ appName }}
    </footer>
  </div>
</template>
