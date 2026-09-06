<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  createAdminVenue,
  fetchAdminVenues,
} from '@/services/adminCatalog'
import type { Venue } from '@/types/database'

const venues = ref<Venue[]>([])
const loading = ref(true)
const saving = ref(false)
const errorMessage = ref('')
const showForm = ref(false)

const form = ref({
  name: '',
  address: '',
  business_mode: 'self_operated' as 'self_operated' | 'external_center',
  is_active: true,
  is_public: true,
})

async function loadData() {
  venues.value = await fetchAdminVenues()
}

async function saveVenue() {
  errorMessage.value = ''

  if (!form.value.name.trim()) {
    errorMessage.value = '請填寫場地名稱'
    return
  }

  saving.value = true

  try {
    const created = await createAdminVenue(form.value)
    venues.value.push(created)
    venues.value.sort((a, b) => a.name.localeCompare(b.name, 'zh-TW'))

    form.value = {
      name: '',
      address: '',
      business_mode: 'self_operated',
      is_active: true,
      is_public: true,
    }

    showForm.value = false
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '新增場地失敗'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  try {
    await loadData()
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '場地資料載入失敗'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="mx-auto max-w-5xl">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-xl font-bold text-gray-900">場地管理</h1>
        <p class="mt-1 text-sm text-gray-500">
          新增與管理上課場地。
        </p>
      </div>

      <button
        type="button"
        class="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white"
        @click="showForm = true"
      >
        ＋ 新增場地
      </button>
    </div>

    <div
      v-if="showForm"
      class="mt-6 rounded-lg border border-gray-200 bg-white p-5"
    >
      <div class="flex items-center justify-between">
        <h2 class="font-bold">新增場地</h2>
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
          <span class="mb-1 block text-gray-600">場地名稱</span>
          <input
            v-model="form.name"
            type="text"
            placeholder="例如：福和路教室"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">地址</span>
          <input
            v-model="form.address"
            type="text"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">場地類型</span>
          <select
            v-model="form.business_mode"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option value="self_operated">自行招生教室</option>
            <option value="external_center">外部運動中心</option>
          </select>
        </label>
      </div>

      <div class="mt-4 flex gap-5 text-sm">
        <label class="flex items-center gap-2">
          <input v-model="form.is_active" type="checkbox" />
          啟用場地
        </label>

        <label class="flex items-center gap-2">
          <input v-model="form.is_public" type="checkbox" />
          前台可見
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
          @click="saveVenue"
        >
          {{ saving ? '儲存中...' : '儲存場地' }}
        </button>
      </div>
    </div>

    <p v-if="loading" class="mt-6 text-sm text-gray-500">載入中...</p>

    <div v-else class="mt-6 overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr class="text-left text-gray-500">
            <th class="py-2 pr-4">場地</th>
            <th class="py-2 pr-4">地址</th>
            <th class="py-2 pr-4">類型</th>
            <th class="py-2 pr-4">狀態</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-100">
          <tr v-for="venue in venues" :key="venue.id">
            <td class="py-3 pr-4 font-medium">{{ venue.name }}</td>
            <td class="py-3 pr-4">{{ venue.address || '—' }}</td>
            <td class="py-3 pr-4">
              {{ venue.business_mode === 'self_operated' ? '自行招生教室' : '外部運動中心' }}
            </td>
            <td class="py-3 pr-4">
              {{ venue.is_active ? '啟用' : '停用' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
