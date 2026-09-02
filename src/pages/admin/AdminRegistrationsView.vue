<script setup lang="ts">
/**
 * Admin 報名清單（唯讀，Registration MVP P0 範圍）。
 *
 * 完整的 Admin CRUD／報表／篩選 UI 留待 P1（REGISTRATION_MVP_PLAN.md 第 A
 * 節），這裡先提供最小可用的「依班級/期別篩選 + 依學生姓名/手機搜尋」。
 */
import { ref, computed, onMounted } from 'vue'
import { fetchAllRegistrationsForAdmin } from '@/services/registrations'

type AdminRegistrationRow = Awaited<ReturnType<typeof fetchAllRegistrationsForAdmin>>[number]

const registrations = ref<AdminRegistrationRow[]>([])
const loading = ref(true)
const errorMessage = ref('')
const classFilter = ref('')
const searchText = ref('')

const STATUS_TEXT: Record<string, string> = {
  active: '有效',
  cancelled: '已取消',
}

const classOptions = computed(() => {
  const names = new Set(registrations.value.map((r) => r.class_name))
  return Array.from(names).sort()
})

const filteredRegistrations = computed(() => {
  return registrations.value.filter((r) => {
    if (classFilter.value && r.class_name !== classFilter.value) return false
    if (searchText.value) {
      const needle = searchText.value.trim()
      const haystack = `${r.student_name ?? ''} ${r.student_phone ?? ''}`
      if (!haystack.includes(needle)) return false
    }
    return true
  })
})

onMounted(async () => {
  try {
    registrations.value = await fetchAllRegistrationsForAdmin()
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '報名資料載入失敗'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="mx-auto max-w-4xl">
    <h1 class="text-xl font-bold text-gray-900">報名清單（唯讀）</h1>

    <p v-if="loading" class="mt-4 text-sm text-gray-500">載入中...</p>
    <p v-if="errorMessage" class="mt-4 text-sm text-red-600">{{ errorMessage }}</p>

    <div v-if="!loading && !errorMessage" class="mt-4 flex flex-wrap gap-3">
      <select v-model="classFilter" class="rounded border border-gray-300 px-3 py-2 text-sm">
        <option value="">全部班級</option>
        <option v-for="name in classOptions" :key="name" :value="name">{{ name }}</option>
      </select>
      <input
        v-model="searchText"
        type="text"
        placeholder="搜尋學生姓名或手機"
        class="rounded border border-gray-300 px-3 py-2 text-sm"
      />
    </div>

    <div v-if="!loading && !errorMessage" class="mt-4 overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr class="text-left text-gray-500">
            <th class="py-2 pr-4">學生</th>
            <th class="py-2 pr-4">手機</th>
            <th class="py-2 pr-4">班級</th>
            <th class="py-2 pr-4">場地／期別</th>
            <th class="py-2 pr-4">報名時間</th>
            <th class="py-2 pr-4">狀態</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <tr v-for="reg in filteredRegistrations" :key="reg.id">
            <td class="py-2 pr-4">{{ reg.student_name ?? '（未填寫姓名）' }}</td>
            <td class="py-2 pr-4">{{ reg.student_phone }}</td>
            <td class="py-2 pr-4">{{ reg.class_name }}</td>
            <td class="py-2 pr-4">{{ reg.venue_name }} ・ {{ reg.term_name }}</td>
            <td class="py-2 pr-4">{{ new Date(reg.created_at).toLocaleString('zh-TW') }}</td>
            <td class="py-2 pr-4">{{ STATUS_TEXT[reg.status] ?? reg.status }}</td>
          </tr>
        </tbody>
      </table>

      <p v-if="filteredRegistrations.length === 0" class="mt-4 text-sm text-gray-500">
        沒有符合篩選條件的報名紀錄。
      </p>
    </div>
  </section>
</template>
