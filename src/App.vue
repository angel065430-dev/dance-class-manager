<script setup lang="ts">
import { onMounted } from 'vue'
import AppShell from '@/layouts/AppShell.vue'
import { useAuth } from '@/composables/useAuth'

const { init } = useAuth()

onMounted(() => {
  // 初始化登入狀態（讀取既有 session，並訂閱後續的登入/登出事件）。
  void init()
})
</script>

<template>
  <AppShell>
    <RouterView />
  </AppShell>
</template>
