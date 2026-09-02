<script setup lang="ts">
/** 學生「我的報名」唯讀清單。 */
import { ref, onMounted } from 'vue'
import { fetchMyRegistrations } from '@/services/registrations'
import type { RegistrationWithClass } from '@/types/database'

const registrations = ref<RegistrationWithClass[]>([])
const loading = ref(true)
const errorMessage = ref('')

const STATUS_TEXT: Record<string, string> = {
  active: '有效',
  cancelled: '已取消',
}

onMounted(async () => {
  try {
    registrations.value = await fetchMyRegistrations()
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '報名紀錄載入失敗'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="mx-auto max-w-2xl">
    <h1 class="text-xl font-bold text-gray-900">我的報名</h1>

    <p v-if="loading" class="mt-4 text-sm text-gray-500">載入中...</p>
    <p v-if="errorMessage" class="mt-4 text-sm text-red-600">{{ errorMessage }}</p>

    <p
      v-if="!loading && registrations.length === 0 && !errorMessage"
      class="mt-4 text-sm text-gray-500"
    >
      目前還沒有任何報名紀錄。
      <RouterLink to="/courses" class="underline">去瀏覽課程</RouterLink>
    </p>

    <ul v-if="registrations.length > 0" class="mt-4 space-y-3">
      <li v-for="reg in registrations" :key="reg.id" class="rounded border border-gray-200 p-4">
        <p class="font-medium text-gray-900">{{ reg.class_name }}</p>
        <p class="text-sm text-gray-500">{{ reg.venue_name }} ・ {{ reg.term_name }}</p>
        <p class="text-sm text-gray-500">
          報名時間：{{ new Date(reg.created_at).toLocaleString('zh-TW') }}
        </p>
        <p class="text-sm" :class="reg.status === 'active' ? 'text-green-700' : 'text-gray-400'">
          狀態：{{ STATUS_TEXT[reg.status] ?? reg.status }}
        </p>
      </li>
    </ul>
  </section>
</template>
