<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  createAdminTerm,
  fetchAdminTerms,
  fetchAdminVenues,
} from '@/services/adminCatalog'
import type { Term, Venue } from '@/types/database'

const venues = ref<Venue[]>([])
const terms = ref<Term[]>([])
const loading = ref(true)
const saving = ref(false)
const errorMessage = ref('')
const showForm = ref(false)

const form = ref({
  venue_id: '',
  name: '',
  start_date: '',
  end_date: '',
  is_active: true,
})

const venueMap = computed(
  () => new Map(venues.value.map((venue) => [venue.id, venue])),
)

async function saveTerm() {
  errorMessage.value = ''

  if (
    !form.value.venue_id ||
    !form.value.name.trim() ||
    !form.value.start_date ||
    !form.value.end_date
  ) {
    errorMessage.value = '請填寫場地、期別名稱與日期'
    return
  }

  if (form.value.end_date < form.value.start_date) {
    errorMessage.value = '結束日期不可早於開始日期'
    return
  }

  saving.value = true

  try {
    const created = await createAdminTerm(form.value)
    terms.value.unshift(created)

    form.value = {
      venue_id: '',
      name: '',
      start_date: '',
      end_date: '',
      is_active: true,
    }

    showForm.value = false
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '新增期別失敗'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  try {
    const [venueRows, termRows] = await Promise.all([
      fetchAdminVenues(),
      fetchAdminTerms(),
    ])

    venues.value = venueRows
    terms.value = termRows
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '期別資料載入失敗'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="mx-auto max-w-5xl">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-xl font-bold text-gray-900">期別管理</h1>
        <p class="mt-1 text-sm text-gray-500">
          每個期別都會歸屬於一個場地。
        </p>
      </div>

      <button
        type="button"
        class="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white"
        @click="showForm = true"
      >
        ＋ 新增期別
      </button>
    </div>

    <div
      v-if="showForm"
      class="mt-6 rounded-lg border border-gray-200 bg-white p-5"
    >
      <div class="flex items-center justify-between">
        <h2 class="font-bold">新增期別</h2>
        <button
          type="button"
          class="text-sm text-gray-500"
          @click="showForm = false"
        >
          關閉
        </button>
      </div>

      <div class="mt-4 grid gap-4 md:grid-cols-2">
        <label class="text-sm">
          <span class="mb-1 block text-gray-600">場地</span>
          <select
            v-model="form.venue_id"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option value="">請選擇場地</option>
            <option
              v-for="venue in venues"
              :key="venue.id"
              :value="venue.id"
            >
              {{ venue.name }}
            </option>
          </select>
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">期別名稱</span>
          <input
            v-model="form.name"
            type="text"
            placeholder="例如：2026年12月–2027年1月"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">開始日期</span>
          <input
            v-model="form.start_date"
            type="date"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">結束日期</span>
          <input
            v-model="form.end_date"
            type="date"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>
      </div>

      <div class="mt-4 text-sm">
        <label class="flex items-center gap-2">
          <input v-model="form.is_active" type="checkbox" />
          啟用期別
        </label>
      </div>

      <p v-if="errorMessage" class="mt-4 text-sm text-red-600">
        {{ errorMessage }}
      </p>

      <div class="mt-5 flex justify-end">
        <button
          type="button"
          :disabled="saving"
          class="rounded bg-gray-900 px-5 py-2 text-sm font-medium text-white disabled:opacity-50"
          @click="saveTerm"
        >
          {{ saving ? '儲存中...' : '儲存期別' }}
        </button>
      </div>
    </div>

    <p v-if="loading" class="mt-6 text-sm text-gray-500">載入中...</p>

    <div v-else class="mt-6 overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr class="text-left text-gray-500">
            <th class="py-2 pr-4">期別</th>
            <th class="py-2 pr-4">場地</th>
            <th class="py-2 pr-4">日期</th>
            <th class="py-2 pr-4">狀態</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-100">
          <tr v-for="term in terms" :key="term.id">
            <td class="py-3 pr-4 font-medium">{{ term.name }}</td>
            <td class="py-3 pr-4">
              {{ venueMap.get(term.venue_id)?.name ?? '未知場地' }}
            </td>
            <td class="py-3 pr-4">
              {{ term.start_date }} ～ {{ term.end_date }}
            </td>
            <td class="py-3 pr-4">
              {{ term.is_active ? '啟用' : '停用' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
