<script setup lang="ts">
/**
 * 公開課程瀏覽 + 多選期課報名頁（Registration MVP 核心路徑）。
 *
 * 任何人都可以瀏覽（含名額顯示，僅供參考）；只有登入的學生可以勾選送出。
 * 送出後採「全部成功或全部失敗」（REGISTRATION_MVP_PLAN.md 第 C 節），
 * 失敗時不建立任何資料，可直接調整勾選後重新送出（重新送出一律使用
 * 新產生的 idempotency key）。
 */
import { ref, onMounted } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { fetchOpenClasses } from '@/services/classes'
import {
  fetchPublicClassSessions,
  type PublicClassSession,
} from '@/services/classSessions'
import {
  submitFullTermRegistrations,
  generateIdempotencyKey,
} from '@/services/registrations'
import type {
  ClassWithAvailability,
  SubmitRegistrationsResult,
} from '@/types/database'

const { isLoggedIn, isAdmin } = useAuth()

const classes = ref<ClassWithAvailability[]>([])
const sessionsByClass = ref<Record<string, PublicClassSession[]>>({})
const selected = ref<Set<string>>(new Set())
const loading = ref(true)
const loadError = ref('')
const submitting = ref(false)
const result = ref<SubmitRegistrationsResult | null>(null)

const FAILURE_REASON_TEXT: Record<string, string> = {
  not_found: '課程不存在',
  not_open: '目前未開放報名',
  already_registered: '你已經報名過這堂課',
  full: '名額已滿',
}

async function loadClasses() {
  loading.value = true
  loadError.value = ''

  try {
    classes.value = await fetchOpenClasses()

    const sessions = await fetchPublicClassSessions(
      classes.value.map((cls) => cls.id),
    )

    sessionsByClass.value = sessions.reduce<
      Record<string, PublicClassSession[]>
    >((acc, session) => {
      if (!acc[session.class_id]) {
        acc[session.class_id] = []
      }

      acc[session.class_id].push(session)
      return acc
    }, {})
  } catch (err) {
    loadError.value = err instanceof Error ? err.message : '課程載入失敗'
  } finally {
    loading.value = false
  }
}

function formatWeekdays(weekdays: number[]) {
  const labels: Record<number, string> = {
    0: '週日',
    1: '週一',
    2: '週二',
    3: '週三',
    4: '週四',
    5: '週五',
    6: '週六',
  }

  return weekdays.map((day) => labels[day] ?? '').filter(Boolean).join('、')
}
function formatSessionDate(date: string) {
  const [year, month, day] = date.split('-').map(Number)

  if (!year || !month || !day) {
    return date
  }

  const localDate = new Date(year, month - 1, day)

  const weekday = new Intl.DateTimeFormat('zh-TW', {
    weekday: 'short',
  }).format(localDate)

  return `${month}/${day}（${weekday}）`
}

function scheduledSessions(classId: string) {
  return (sessionsByClass.value[classId] ?? []).filter(
    (session) => session.status === 'scheduled',
  )
}

function cancelledSessions(classId: string) {
  return (sessionsByClass.value[classId] ?? []).filter(
    (session) => session.status === 'cancelled',
  )
}

function toggleSelect(classId: string) {
  if (selected.value.has(classId)) {
    selected.value.delete(classId)
  } else {
    selected.value.add(classId)
  }

  selected.value = new Set(selected.value)
}

async function handleSubmit() {
  if (selected.value.size === 0) return

  submitting.value = true
  result.value = null

  try {
    result.value = await submitFullTermRegistrations(
      Array.from(selected.value),
      generateIdempotencyKey(),
    )

    if (result.value.success) {
      selected.value = new Set()
      await loadClasses()
    }
  } catch (err) {
    result.value = {
      success: false,
      failures: [],
      order_ids: [],
      registration_ids: [],
    }

    loadError.value =
      err instanceof Error ? err.message : '報名送出失敗，請稍後再試'
  } finally {
    submitting.value = false
  }
}

onMounted(loadClasses)
</script>

<template>
  <section class="mx-auto max-w-2xl">
    <h1 class="text-xl font-bold text-gray-900">目前開放報名的期課</h1>

    <p v-if="!isLoggedIn" class="mt-2 text-sm text-gray-600">
      <RouterLink to="/login" class="underline">登入</RouterLink>
      或
      <RouterLink to="/register" class="underline">註冊</RouterLink>
      後即可選課報名。
    </p>

    <p v-if="loading" class="mt-4 text-sm text-gray-500">載入中...</p>

    <p v-if="loadError" class="mt-4 text-sm text-red-600">
      {{ loadError }}
    </p>

    <ul
      v-if="!loading && classes.length > 0"
      class="mt-4 space-y-3"
    >
      <li
        v-for="cls in classes"
        :key="cls.id"
        class="flex items-center justify-between rounded border border-gray-200 p-4"
      >
        <div>
          <p class="font-medium text-gray-900">
            {{ cls.name }}
          </p>

          <p class="text-sm text-gray-500">
            {{ cls.venue_name }} ・ {{ cls.term_name }}
          </p>

          <p class="mt-1 text-sm text-gray-600">
            {{ formatWeekdays(cls.weekdays) }}
            {{ cls.start_time.slice(0, 5) }}–{{ cls.end_time.slice(0, 5) }}
          </p>

          <p class="mt-1 text-sm font-medium text-gray-800">
            上課共 {{ scheduledSessions(cls.id).length }} 堂 ・
            整期 NT$ {{ cls.full_term_price }}
          </p>

          <p
            v-if="scheduledSessions(cls.id).length > 0"
            class="mt-2 text-sm text-gray-600"
          >
            上課日期：
            {{
              scheduledSessions(cls.id)
                .map((session) => formatSessionDate(session.session_date))
                .join('、')
            }}
          </p>

          <p
            v-if="cancelledSessions(cls.id).length > 0"
            class="mt-1 text-sm text-red-600"
          >
            停課：
            {{
              cancelledSessions(cls.id)
                .map((session) => formatSessionDate(session.session_date))
                .join('、')
            }}
          </p>

          <p
            v-if="(sessionsByClass[cls.id] ?? []).length === 0"
            class="mt-2 text-sm text-amber-600"
          >
            尚未設定實際上課日期
          </p>

          <p
            class="mt-1 text-sm"
            :class="
              cls.remaining_seats === 0
                ? 'text-red-600'
                : 'text-gray-500'
            "
          >
            剩餘名額：{{ cls.remaining_seats ?? '—' }}（僅供參考）
          </p>
        </div>

        <label
          v-if="isLoggedIn && !isAdmin"
          class="flex items-center gap-2"
        >
          <input
            type="checkbox"
            :checked="selected.has(cls.id)"
            :disabled="cls.remaining_seats === 0"
            @change="toggleSelect(cls.id)"
          />
        </label>
      </li>
    </ul>

    <p
      v-if="!loading && classes.length === 0 && !loadError"
      class="mt-4 text-sm text-gray-500"
    >
      目前沒有開放報名的期課。
    </p>

    <div
      v-if="isLoggedIn && !isAdmin && classes.length > 0"
      class="mt-6"
    >
      <button
        type="button"
        :disabled="selected.size === 0 || submitting"
        class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
        @click="handleSubmit"
      >
        {{
          submitting
            ? '送出中...'
            : `送出報名（已選 ${selected.size} 堂）`
        }}
      </button>
    </div>

    <div
      v-if="result"
      class="mt-6 rounded border p-4"
      :class="
        result.success
          ? 'border-green-300 bg-green-50'
          : 'border-red-300 bg-red-50'
      "
    >
      <template v-if="result.success">
        <p class="font-semibold text-green-800">
          報名已送出，名額已為你保留！
        </p>

        <ul class="mt-2 list-disc pl-5 text-sm text-green-800">
          <li
            v-for="c in result.classes"
            :key="c.registration_id"
          >
            {{ c.class_name }}
          </li>
        </ul>

        <p class="mt-3 text-sm text-green-800">
          請前往「我的報名」查看付款資訊並完成付款。
        </p>

        <RouterLink
          to="/my-registrations"
          class="mt-4 inline-block rounded bg-green-700 px-4 py-2 text-sm font-medium text-white"
        >
          前往付款
        </RouterLink>
      </template>

      <template v-else>
        <p class="font-medium text-red-800">
          報名未成立（全部成功或全部失敗，尚未建立任何一堂課的報名）
        </p>

        <ul
          v-if="result.failures.length > 0"
          class="mt-2 list-disc pl-5 text-sm text-red-800"
        >
          <li
            v-for="f in result.failures"
            :key="f.class_id"
          >
            {{ f.class_name ?? f.class_id }}：
            {{ FAILURE_REASON_TEXT[f.reason] ?? f.reason }}
          </li>
        </ul>

        <p
          v-else
          class="mt-2 text-sm text-red-800"
        >
          {{ loadError }}
        </p>

        <p class="mt-2 text-sm text-red-700">
          請調整勾選後重新送出。
        </p>
      </template>
    </div>
  </section>
</template>


