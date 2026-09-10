<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AdminClassSessionsPanel from '@/components/AdminClassSessionsPanel.vue'
import {
  createAdminClass,
  fetchAdminClasses,
  fetchAdminTerms,
  fetchAdminVenues,
  updateAdminClass,
} from '@/services/adminClasses'
import type { DanceClass, Term, Venue } from '@/types/database'
import { fetchRegistrationSettings, updateRegistrationSettings } from '@/services/registrationSettings'

const venues = ref<Venue[]>([])
const terms = ref<Term[]>([])
const classes = ref<DanceClass[]>([])
const loading = ref(true)
const errorMessage = ref('')
const saving = ref(false)
const saveErrorMessage = ref('')
const discountEnabled = ref(true)
const discountMinClasses = ref(2)
const discountPercent = ref(96)
const discountSaving = ref(false)
const discountMessage = ref('')
const discountError = ref('')

const showCreateForm = ref(false)

const editingClassId = ref<string | null>(null)
const managingSessionsClass = ref<DanceClass | null>(null)
function openSessionsPanel(danceClass: DanceClass) {
  managingSessionsClass.value = danceClass
}
function closeSessionsPanel() {
  managingSessionsClass.value = null
}

const editClass = ref({
  venue_id: '',
  term_id: '',
  name: '',
  class_code: '',
  weekday: 1,
  start_time: '20:30',
  end_time: '21:20',
  capacity: 15,
  full_term_price: 0,
  is_open_for_registration: false,
  is_active: true,
})

const newClass = ref({
  venue_id: '',
  term_id: '',
  name: '',
  class_code: '',
  weekday: 1,
  start_time: '20:30',
  end_time: '21:20',
  capacity: 15,
  full_term_price: 0,
  is_open_for_registration: false,
  is_active: true,
})

const WEEKDAY_TEXT: Record<number, string> = {
  0: '日',
  1: '一',
  2: '二',
  3: '三',
  4: '四',
  5: '五',
  6: '六',
}

const venueMap = computed(() => new Map(venues.value.map((venue) => [venue.id, venue])))
const termMap = computed(() => new Map(terms.value.map((term) => [term.id, term])))

const availableTerms = computed(() => {
  if (!newClass.value.venue_id) return terms.value
  return terms.value.filter((term) => term.venue_id === newClass.value.venue_id)
})

const editAvailableTerms = computed(() => {
  if (!editClass.value.venue_id) return terms.value
  return terms.value.filter((term) => term.venue_id === editClass.value.venue_id)
})

function formatWeekdays(weekdays: number[]) {
  return weekdays.map((day) => `週${WEEKDAY_TEXT[day] ?? day}`).join('、')
}

function formatTime(time: string) {
  return time.slice(0, 5)
}

function formatPrice(price: number | null) {
  if (price === null) return '未設定'
  return `NT$${Number(price).toLocaleString('zh-TW')}`
}

function openCreateForm() {
  showCreateForm.value = true
}

function closeCreateForm() {
  showCreateForm.value = false
}

function openEditForm(danceClass: DanceClass) {
  saveErrorMessage.value = ''
  editingClassId.value = danceClass.id

  editClass.value = {
    venue_id: danceClass.venue_id,
    term_id: danceClass.term_id,
    name: danceClass.name,
    class_code: danceClass.class_code ?? '',
    weekday: danceClass.weekdays[0] ?? 1,
    start_time: formatTime(danceClass.start_time),
    end_time: formatTime(danceClass.end_time),
    capacity: danceClass.capacity,
    full_term_price: danceClass.full_term_price,
    is_open_for_registration: danceClass.is_open_for_registration,
    is_active: danceClass.is_active,
  }
}

function closeEditForm() {
  editingClassId.value = null
  saveErrorMessage.value = ''
}


async function saveNewClass() {
  saveErrorMessage.value = ''

  if (
    !newClass.value.venue_id ||
    !newClass.value.term_id ||
    !newClass.value.name.trim()
  ) {
    saveErrorMessage.value = '請填寫場地、期別與課程名稱'
    return
  }

  if (newClass.value.capacity <= 0) {
    saveErrorMessage.value = '名額必須大於 0'
    return
  }

  if (newClass.value.full_term_price < 0) {
    saveErrorMessage.value = '期課費用不可小於 0'
    return
  }

  saving.value = true

  try {
    const venue = venueMap.value.get(newClass.value.venue_id)

    const created = await createAdminClass({
      venue_id: newClass.value.venue_id,
      term_id: newClass.value.term_id,
      name: newClass.value.name,
      class_code: newClass.value.class_code || null,
      weekdays: [newClass.value.weekday],
      start_time: newClass.value.start_time,
      end_time: newClass.value.end_time,
      capacity: newClass.value.capacity,
      business_mode: venue?.business_mode ?? 'self_operated',
      full_term_price: newClass.value.full_term_price,
      is_open_for_registration: newClass.value.is_open_for_registration,
      is_active: newClass.value.is_active,
    })

    classes.value.push(created)
    classes.value.sort((a, b) => a.name.localeCompare(b.name, 'zh-TW'))

    showCreateForm.value = false
  } catch (err) {
    saveErrorMessage.value =
      err instanceof Error ? err.message : '新增期課失敗'
  } finally {
    saving.value = false
  }
}
async function saveEditedClass() {
  saveErrorMessage.value = ''

  if (
    !editingClassId.value ||
    !editClass.value.venue_id ||
    !editClass.value.term_id ||
    !editClass.value.name.trim()
  ) {
    saveErrorMessage.value = '請填寫場地、期別與課程名稱'
    return
  }

  if (editClass.value.capacity <= 0) {
    saveErrorMessage.value = '名額必須大於 0'
    return
  }

  if (editClass.value.full_term_price < 0) {
    saveErrorMessage.value = '期課費用不可小於 0'
    return
  }

  saving.value = true

  try {
    const venue = venueMap.value.get(editClass.value.venue_id)

    const updated = await updateAdminClass(editingClassId.value, {
      venue_id: editClass.value.venue_id,
      term_id: editClass.value.term_id,
      name: editClass.value.name,
      class_code: editClass.value.class_code || null,
      weekdays: [editClass.value.weekday],
      start_time: editClass.value.start_time,
      end_time: editClass.value.end_time,
      capacity: editClass.value.capacity,
      business_mode: venue?.business_mode ?? 'self_operated',
      full_term_price: editClass.value.full_term_price,
      is_open_for_registration: editClass.value.is_open_for_registration,
      is_active: editClass.value.is_active,
    })

    const index = classes.value.findIndex((item) => item.id === updated.id)

    if (index !== -1) {
      classes.value[index] = updated
    }

    editingClassId.value = null
  } catch (err) {
    saveErrorMessage.value =
      err instanceof Error ? err.message : '更新期課失敗'
  } finally {
    saving.value = false
  }
}

async function saveDiscountSettings() {
  discountMessage.value = ''
  discountError.value = ''
  if (discountMinClasses.value < 2 || discountPercent.value <= 0 || discountPercent.value > 100) {
    discountError.value = '最低堂數至少 2 堂，折扣百分比需大於 0 且不超過 100。'
    return
  }
  discountSaving.value = true
  try {
    const saved = await updateRegistrationSettings({
      enabled: discountEnabled.value,
      min_full_term_classes: discountMinClasses.value,
      full_term_discount_percent: discountPercent.value,
    })
    discountEnabled.value = saved.enabled
    discountMinClasses.value = saved.min_full_term_classes
    discountPercent.value = saved.full_term_discount_percent
    discountMessage.value = '多堂期課優惠設定已儲存。'
  } catch (err) {
    discountError.value = err instanceof Error ? err.message : '優惠設定儲存失敗'
  } finally {
    discountSaving.value = false
  }
}

onMounted(async () => {
  try {
    const [venueRows, termRows, classRows, discountSettings] = await Promise.all([
      fetchAdminVenues(),
      fetchAdminTerms(),
      fetchAdminClasses(),
      fetchRegistrationSettings(),
    ])

    venues.value = venueRows
    terms.value = termRows
    classes.value = classRows
    discountEnabled.value = discountSettings.enabled
    discountMinClasses.value = discountSettings.min_full_term_classes
    discountPercent.value = discountSettings.full_term_discount_percent
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '期課資料載入失敗'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="mx-auto max-w-5xl">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="text-xl font-bold text-gray-900">期課管理</h1>
        <p class="mt-1 text-sm text-gray-500">
          管理場地、期別、課程費用、名額與報名開放狀態。
        </p>
      </div>

      <button
        type="button"
        class="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white"
        @click="openCreateForm"
      >
        ＋ 新增期課
      </button>
    </div>

    <div class="mt-6 rounded-lg border border-gray-200 bg-white p-5">
      <h2 class="font-bold text-gray-900">多堂期課優惠</h2>
      <p class="mt-1 text-sm text-gray-500">同一期、同一次報名達最低堂數時，由後端自動套用折扣。</p>
      <div class="mt-4 grid gap-4 md:grid-cols-3">
        <label class="flex items-center gap-2 text-sm">
          <input v-model="discountEnabled" type="checkbox" />
          <span>啟用優惠</span>
        </label>
        <label class="text-sm">
          <span class="mb-1 block text-gray-600">最低期課堂數</span>
          <input v-model.number="discountMinClasses" type="number" min="2" class="w-full rounded border border-gray-300 px-3 py-2" />
        </label>
        <label class="text-sm">
          <span class="mb-1 block text-gray-600">折扣百分比（96 = 96 折）</span>
          <input v-model.number="discountPercent" type="number" min="1" max="100" step="0.01" class="w-full rounded border border-gray-300 px-3 py-2" />
        </label>
      </div>
      <p v-if="discountMessage" class="mt-3 text-sm text-green-700">{{ discountMessage }}</p>
      <p v-if="discountError" class="mt-3 text-sm text-red-600">{{ discountError }}</p>
      <button type="button" :disabled="discountSaving" class="mt-4 rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50" @click="saveDiscountSettings">
        {{ discountSaving ? '儲存中...' : '儲存優惠設定' }}
      </button>
    </div>

    <div
      v-if="showCreateForm"
      class="mt-6 rounded-lg border border-gray-200 bg-white p-5"
    >
      <div class="flex items-center justify-between gap-4">
        <h2 class="font-bold text-gray-900">新增期課</h2>

        <button
          type="button"
          class="text-sm text-gray-500"
          @click="closeCreateForm"
        >
          關閉
        </button>
      </div>

      <div class="mt-4 grid gap-4 md:grid-cols-2">
        <label class="text-sm">
          <span class="mb-1 block text-gray-600">場地</span>
          <select
            v-model="newClass.venue_id"
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
          <span class="mb-1 block text-gray-600">期別</span>
          <select
            v-model="newClass.term_id"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option value="">請選擇期別</option>
            <option
              v-for="term in availableTerms"
              :key="term.id"
              :value="term.id"
            >
              {{ term.name }}
            </option>
          </select>
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">課程名稱</span>
          <input
            v-model="newClass.name"
            type="text"
            placeholder="例如：週一 Zumba®"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">課程代號</span>
          <input v-model="newClass.class_code" type="text" placeholder="例如：F120" class="w-full rounded border border-gray-300 px-3 py-2 uppercase" />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">星期</span>
          <select
            v-model.number="newClass.weekday"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option v-for="day in 7" :key="day - 1" :value="day - 1">
              週{{ WEEKDAY_TEXT[day - 1] }}
            </option>
          </select>
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">開始時間</span>
          <input
            v-model="newClass.start_time"
            type="time"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">結束時間</span>
          <input
            v-model="newClass.end_time"
            type="time"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">名額</span>
          <input
            v-model.number="newClass.capacity"
            type="number"
            min="0"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">期課費用</span>
          <input
            v-model.number="newClass.full_term_price"
            type="number"
            min="0"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>
      </div>

      <div class="mt-4 flex flex-wrap gap-5 text-sm">
        <label class="flex items-center gap-2">
          <input
            v-model="newClass.is_open_for_registration"
            type="checkbox"
          />
          開放報名
        </label>

        <label class="flex items-center gap-2">
          <input
            v-model="newClass.is_active"
            type="checkbox"
          />
          啟用課程
        </label>
      </div>


      <div class="mt-5 flex justify-end">
        <button
          type="button"
          :disabled="saving"
          class="rounded bg-gray-900 px-5 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          @click="saveNewClass"
        >
          {{ saving ? '儲存中...' : '儲存期課' }}
        </button>
      </div>
    </div>

    <div
      v-if="editingClassId"
      class="mt-6 rounded-lg border border-gray-200 bg-white p-5"
    >
      <div class="flex items-center justify-between gap-4">
        <h2 class="font-bold text-gray-900">編輯期課</h2>

        <button
          type="button"
          class="text-sm text-gray-500"
          @click="closeEditForm"
        >
          關閉
        </button>
      </div>

      <div class="mt-4 grid gap-4 md:grid-cols-2">
        <label class="text-sm">
          <span class="mb-1 block text-gray-600">場地</span>
          <select
            v-model="editClass.venue_id"
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
          <span class="mb-1 block text-gray-600">期別</span>
          <select
            v-model="editClass.term_id"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option value="">請選擇期別</option>
            <option
              v-for="term in editAvailableTerms"
              :key="term.id"
              :value="term.id"
            >
              {{ term.name }}
            </option>
          </select>
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">課程名稱</span>
          <input
            v-model="editClass.name"
            type="text"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">課程代號</span>
          <input v-model="editClass.class_code" type="text" placeholder="例如：F120" class="w-full rounded border border-gray-300 px-3 py-2 uppercase" />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">星期</span>
          <select
            v-model.number="editClass.weekday"
            class="w-full rounded border border-gray-300 px-3 py-2"
          >
            <option v-for="day in 7" :key="day - 1" :value="day - 1">
              週{{ WEEKDAY_TEXT[day - 1] }}
            </option>
          </select>
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">開始時間</span>
          <input
            v-model="editClass.start_time"
            type="time"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">結束時間</span>
          <input
            v-model="editClass.end_time"
            type="time"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">名額</span>
          <input
            v-model.number="editClass.capacity"
            type="number"
            min="1"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>

        <label class="text-sm">
          <span class="mb-1 block text-gray-600">期課費用</span>
          <input
            v-model.number="editClass.full_term_price"
            type="number"
            min="0"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />
        </label>
      </div>

      <div class="mt-4 flex flex-wrap gap-5 text-sm">
        <label class="flex items-center gap-2">
          <input
            v-model="editClass.is_open_for_registration"
            type="checkbox"
          />
          開放報名
        </label>

        <label class="flex items-center gap-2">
          <input
            v-model="editClass.is_active"
            type="checkbox"
          />
          啟用課程
        </label>
      </div>

      <p v-if="saveErrorMessage" class="mt-4 text-sm text-red-600">
        {{ saveErrorMessage }}
      </p>

      <div class="mt-5 flex justify-end">
        <button
          type="button"
          :disabled="saving"
          class="rounded bg-gray-900 px-5 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          @click="saveEditedClass"
        >
          {{ saving ? '儲存中...' : '儲存修改' }}
        </button>
      </div>
    </div>

    <AdminClassSessionsPanel
      v-if="managingSessionsClass"
      :class-id="managingSessionsClass.id"
      :class-name="managingSessionsClass.name"
      @close="closeSessionsPanel"
    />

    <p v-if="loading" class="mt-6 text-sm text-gray-500">載入中...</p>

    <p v-else-if="errorMessage" class="mt-6 text-sm text-red-600">
      {{ errorMessage }}
    </p>

    <div v-else class="mt-6 overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead>
          <tr class="text-left text-gray-500">
            <th class="py-2 pr-4">課程</th>
            <th class="py-2 pr-4">場地</th>
            <th class="py-2 pr-4">期別</th>
            <th class="py-2 pr-4">上課時間</th>
            <th class="py-2 pr-4">期課費用</th>
            <th class="py-2 pr-4">名額</th>
            <th class="py-2 pr-4">報名狀態</th>
            <th class="py-2 pr-4">操作</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-100">
          <tr v-for="danceClass in classes" :key="danceClass.id">
            <td class="py-3 pr-4 font-medium text-gray-900">
              {{ danceClass.class_code ? `${danceClass.class_code}｜` : '' }}{{ danceClass.name }}
            </td>

            <td class="py-3 pr-4">
              {{ venueMap.get(danceClass.venue_id)?.name ?? '未知場地' }}
            </td>

            <td class="py-3 pr-4">
              {{ termMap.get(danceClass.term_id)?.name ?? '未知期別' }}
            </td>

            <td class="py-3 pr-4">
              {{ formatWeekdays(danceClass.weekdays) }}
              {{ formatTime(danceClass.start_time) }}–{{ formatTime(danceClass.end_time) }}
            </td>

            <td class="py-3 pr-4">
              {{ formatPrice(danceClass.full_term_price) }}
            </td>

            <td class="py-3 pr-4">
              {{ danceClass.capacity }} 人
            </td>

            <td class="py-3 pr-4">
              <span
                :class="
                  danceClass.is_open_for_registration
                    ? 'text-green-700'
                    : 'text-gray-500'
                "
              >
                {{ danceClass.is_open_for_registration ? '開放報名' : '未開放' }}
              </span>
            </td>

            <td class="py-3 pr-4">
              <button
                type="button"
                class="rounded border border-gray-300 px-3 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                @click="openEditForm(danceClass)"
              >
                編輯
              </button>
                <button
                  type="button"
                  class="ml-2 rounded border border-gray-300 px-3 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50"
                  @click="openSessionsPanel(danceClass)"
                >
                  上課日期
                </button>
            </td>
          </tr>
        </tbody>
      </table>

      <p v-if="classes.length === 0" class="mt-4 text-sm text-gray-500">
        目前沒有期課資料。
      </p>
    </div>
  </section>
</template>










