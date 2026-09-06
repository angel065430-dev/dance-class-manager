<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import {
  fetchAdminClassSessions,
  generateAdminClassSessions,
  updateAdminClassSessionStatus,
  type AdminClassSession,
  type ClassSessionStatus,
} from '@/services/adminClassSessions'

const props = defineProps<{
  classId: string
  className: string
}>()

const emit = defineEmits<{
  close: []
}>()

const sessions = ref<AdminClassSession[]>([])
const loading = ref(false)
const generating = ref(false)
const updatingSessionId = ref<string | null>(null)
const errorMessage = ref('')
const successMessage = ref('')

function formatDate(date: string) {
  const [year, month, day] = date.split('-').map(Number)

  if (!year || !month || !day) return date

  const localDate = new Date(year, month - 1, day)
  const weekday = new Intl.DateTimeFormat('zh-TW', {
    weekday: 'short',
  }).format(localDate)

  return `${month}/${day}（${weekday}）`
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat('zh-TW', {
    timeZone: 'Asia/Taipei',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

async function loadSessions() {
  loading.value = true
  errorMessage.value = ''

  try {
    sessions.value = await fetchAdminClassSessions(props.classId)
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '上課日期載入失敗'
  } finally {
    loading.value = false
  }
}

async function generateSessions() {
  generating.value = true
  errorMessage.value = ''
  successMessage.value = ''

  try {
    const count = await generateAdminClassSessions(props.classId)
    await loadSessions()
    successMessage.value = `已產生／更新 ${count} 個上課日期`
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '產生上課日期失敗'
  } finally {
    generating.value = false
  }
}

async function changeStatus(
  session: AdminClassSession,
  status: ClassSessionStatus,
) {
  if (session.status === status) return

  updatingSessionId.value = session.id
  errorMessage.value = ''
  successMessage.value = ''

  try {
    const updated = await updateAdminClassSessionStatus(session.id, status)
    const index = sessions.value.findIndex((item) => item.id === updated.id)

    if (index !== -1) {
      sessions.value[index] = updated
    }
  } catch (err) {
    errorMessage.value =
      err instanceof Error ? err.message : '更新上課狀態失敗'
  } finally {
    updatingSessionId.value = null
  }
}

watch(
  () => props.classId,
  () => {
    void loadSessions()
  },
)

onMounted(() => {
  void loadSessions()
})
</script>

<template>
  <div class="mt-6 rounded-lg border border-gray-200 bg-white p-5">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h2 class="font-bold text-gray-900">上課日期管理</h2>
        <p class="mt-1 text-sm text-gray-500">{{ className }}</p>
      </div>

      <button
        type="button"
        class="text-sm text-gray-500"
        @click="emit('close')"
      >
        關閉
      </button>
    </div>

    <div class="mt-4">
      <button
        type="button"
        :disabled="generating"
        class="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
        @click="generateSessions"
      >
        {{ generating ? '產生中...' : '自動產生上課日期' }}
      </button>
    </div>

    <p v-if="successMessage" class="mt-3 text-sm text-green-700">
      {{ successMessage }}
    </p>

    <p v-if="errorMessage" class="mt-3 text-sm text-red-600">
      {{ errorMessage }}
    </p>

    <p v-if="loading" class="mt-4 text-sm text-gray-500">
      載入中...
    </p>

    <div v-else-if="sessions.length > 0" class="mt-5 overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr class="text-left text-gray-500">
            <th class="py-2 pr-4">日期</th>
            <th class="py-2 pr-4">時間</th>
            <th class="py-2 pr-4">狀態</th>
            <th class="py-2 pr-4">操作</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-100">
          <tr
            v-for="session in sessions"
            :key="session.id"
            :class="session.status === 'cancelled' ? 'bg-gray-50 text-gray-400' : ''"
          >
            <td
              class="py-3 pr-4 font-medium"
              :class="session.status === 'cancelled' ? 'line-through' : 'text-gray-900'"
            >
              {{ formatDate(session.session_date) }}
            </td>

            <td class="py-3 pr-4">
              {{ formatTime(session.start_at) }}–{{ formatTime(session.end_at) }}
            </td>

            <td class="py-3 pr-4">
              <span
                v-if="session.status === 'scheduled'"
                class="text-green-700"
              >
                正常上課
              </span>
              <span v-else class="font-medium text-red-600">
                停課
              </span>
            </td>

            <td class="py-3 pr-4">
              <button
                v-if="session.status === 'scheduled'"
                type="button"
                :disabled="updatingSessionId === session.id"
                class="rounded border border-red-300 px-3 py-1 text-xs font-medium text-red-700 disabled:opacity-50"
                @click="changeStatus(session, 'cancelled')"
              >
                設為停課
              </button>

              <button
                v-else
                type="button"
                :disabled="updatingSessionId === session.id"
                class="rounded border border-green-300 px-3 py-1 text-xs font-medium text-green-700 disabled:opacity-50"
                @click="changeStatus(session, 'scheduled')"
              >
                恢復上課
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-else class="mt-4 text-sm text-gray-500">
      尚未產生實際上課日期。
    </p>
  </div>
</template>
