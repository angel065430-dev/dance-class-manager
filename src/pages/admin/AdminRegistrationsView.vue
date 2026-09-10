<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import {
  adminCancelPendingRegistration,
  adminMarkOrderPaid,
  fetchAllRegistrationsForAdmin,
} from '@/services/registrations'
import { fetchAdminClasses } from '@/services/adminClasses'
import { studentDisplayName } from '@/utils/studentNames'
import { groupRowsByOrder } from '@/utils/orderGroups'

type AdminRegistrationRow = Awaited<ReturnType<typeof fetchAllRegistrationsForAdmin>>[number]
type AdminOrderGroup = AdminRegistrationRow & {
  class_names: string[]
  registrations: AdminRegistrationRow[]
}

const registrations = ref<AdminRegistrationRow[]>([])
const classes = ref<Awaited<ReturnType<typeof fetchAdminClasses>>>([])
const loading = ref(true)
const errorMessage = ref('')
const classFilter = ref('')
const searchText = ref('')
const confirmingOrderId = ref<string | null>(null)
const cancellingRegistrationId = ref<string | null>(null)
const actionMessage = ref('')

const PAYMENT_STATUS_TEXT: Record<string, string> = {
  pending: '待付款',
  paid: '已付款',
}

const classOptions = computed(() =>
  classes.value
    .filter((c) => c.is_active)
    .map((c) => c.name)
    .sort(),
)

const orderGroups = computed(() => groupRowsByOrder(registrations.value))

const filteredRegistrations = computed(() => {
  return orderGroups.value.filter((r) => {
    if (classFilter.value && !r.class_names.includes(classFilter.value)) return false

    if (searchText.value) {
      const needle = searchText.value.trim()
      const haystack =
        `${r.student_name ?? ''} ${r.student_line_display_name ?? ''} ${r.student_phone ?? ''} ${r.payment_reference ?? ''}`

      if (!haystack.includes(needle)) return false
    }

    return true
  })
})

function orderHasActive(reg: AdminOrderGroup) {
  return reg.registrations.some((item) => item.status === 'active')
}

function formatCurrency(amount: number) {
  return new Intl.NumberFormat('zh-TW', {
    style: 'currency',
    currency: 'TWD',
    maximumFractionDigits: 0,
  }).format(amount)
}

function formatPaymentMethod(method: AdminRegistrationRow['payment_method']) {
  if (method === 'bank_transfer') return '銀行轉帳'
  if (method === 'line_pay') return 'LINE Pay'
  return '尚未提交'
}

async function loadRegistrations() {
  loading.value = true
  errorMessage.value = ''

  try {
    const [registrationRows, classRows] = await Promise.all([
      fetchAllRegistrationsForAdmin(),
      fetchAdminClasses(),
    ])
    registrations.value = registrationRows
    classes.value = classRows
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '報名資料載入失敗'
  } finally {
    loading.value = false
  }
}

async function confirmPayment(reg: AdminRegistrationRow) {
  const confirmed = window.confirm(
    `確認已收到 ${reg.student_name ?? reg.student_phone ?? '此學生'} 的款項 ${formatCurrency(reg.total_amount)} 嗎？`,
  )

  if (!confirmed) return

  confirmingOrderId.value = reg.order_id
  actionMessage.value = ''
  errorMessage.value = ''

  try {
    await adminMarkOrderPaid(reg.order_id)
    actionMessage.value = '已確認收款。'
    await loadRegistrations()
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '確認收款失敗'
  } finally {
    confirmingOrderId.value = null
  }
}

async function cancelRegistration(reg: AdminRegistrationRow) {
  const confirmed = window.confirm(
    `確定要替 ${reg.student_name ?? reg.student_phone ?? '此學生'} 取消「${reg.class_name}」嗎？\n\n名額會立即釋出，訂單金額及多堂優惠會依剩餘課程重新計算。`,
  )
  if (!confirmed) return

  cancellingRegistrationId.value = reg.id
  actionMessage.value = ''
  errorMessage.value = ''

  try {
    await adminCancelPendingRegistration(reg.id)
    actionMessage.value = `已取消「${reg.class_name}」，名額與訂單金額已更新。`
    await loadRegistrations()
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '取消報名失敗'
  } finally {
    cancellingRegistrationId.value = null
  }
}

onMounted(loadRegistrations)
</script>

<template>
  <section class="mx-auto max-w-6xl">
    <h1 class="text-xl font-bold text-gray-900">報名與付款管理</h1>

    <p v-if="loading" class="mt-4 text-sm text-gray-500">載入中...</p>
    <p v-if="errorMessage" class="mt-4 text-sm text-red-600">{{ errorMessage }}</p>
    <p v-if="actionMessage" class="mt-4 text-sm text-green-700">{{ actionMessage }}</p>

    <div v-if="!loading && !errorMessage" class="mt-4 flex flex-wrap gap-3">
      <select
        v-model="classFilter"
        class="rounded border border-gray-300 px-3 py-2 text-sm"
      >
        <option value="">全部班級</option>
        <option v-for="name in classOptions" :key="name" :value="name">
          {{ name }}
        </option>
      </select>

      <input
        v-model="searchText"
        type="text"
        placeholder="搜尋中文本名、LINE 顯示名字、手機或末五碼"
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
            <th class="py-2 pr-4">金額</th>
            <th class="py-2 pr-4">付款方式</th>
            <th class="py-2 pr-4">末五碼</th>
            <th class="py-2 pr-4">付款狀態</th>
            <th class="py-2 pr-4">報名狀態</th>
            <th class="py-2 pr-4">操作</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-gray-100">
          <tr v-for="reg in filteredRegistrations" :key="reg.order_id">
            <td class="py-3 pr-4 align-top">
              {{ studentDisplayName(reg.student_name, reg.student_line_display_name) }}
            </td>

            <td class="py-3 pr-4 align-top">
              {{ reg.student_phone }}
            </td>

            <td class="py-3 pr-4 align-top">
              <ul class="space-y-2">
                <li
                  v-for="item in reg.registrations"
                  :key="item.id"
                  class="flex min-w-[13rem] items-center justify-between gap-2"
                >
                  <span :class="item.status === 'cancelled' ? 'text-gray-400 line-through' : ''">
                    • {{ item.class_code ? `${item.class_code}｜` : '' }}{{ item.class_name }}
                    <span v-if="item.status === 'cancelled'" class="text-xs">（已取消）</span>
                  </span>
                  <button
                    v-if="item.status === 'active' && reg.payment_status === 'pending'"
                    type="button"
                    class="shrink-0 rounded border border-red-300 px-2 py-1 text-xs font-medium text-red-700 disabled:opacity-50"
                    :disabled="cancellingRegistrationId === item.id"
                    @click="cancelRegistration(item)"
                  >
                    {{ cancellingRegistrationId === item.id ? '取消中...' : '取消' }}
                  </button>
                </li>
              </ul>
            </td>

            <td class="py-3 pr-4 align-top">
              {{ reg.venue_name }} ・ {{ reg.term_name }}
            </td>

            <td class="py-3 pr-4 align-top font-medium">
              {{ formatCurrency(reg.total_amount) }}
            </td>

            <td class="py-3 pr-4 align-top">
              {{ formatPaymentMethod(reg.payment_method) }}
            </td>

            <td class="py-3 pr-4 align-top font-mono">
              {{ reg.payment_reference ?? '—' }}
            </td>

            <td class="py-3 pr-4 align-top">
              <span
                class="font-medium"
                :class="reg.payment_status === 'paid' ? 'text-green-700' : 'text-amber-600'"
              >
                {{ PAYMENT_STATUS_TEXT[reg.payment_status] ?? reg.payment_status }}
              </span>
            </td>

            <td class="py-3 pr-4 align-top">
              {{ orderHasActive(reg) ? '有效' : '已取消' }}
            </td>

            <td class="py-3 pr-4 align-top">
              <button
                v-if="reg.payment_status === 'pending' && orderHasActive(reg)"
                type="button"
                class="rounded bg-green-700 px-3 py-2 text-xs font-medium text-white disabled:opacity-50"
                :disabled="confirmingOrderId === reg.order_id"
                @click="confirmPayment(reg)"
              >
                {{ confirmingOrderId === reg.order_id ? '處理中...' : '確認收款' }}
              </button>

              <span v-else-if="reg.payment_status === 'paid'" class="text-xs text-green-700">
                已確認
              </span>
              <span v-else class="text-xs text-gray-500">無需付款</span>
            </td>
          </tr>
        </tbody>
      </table>

      <p
        v-if="filteredRegistrations.length === 0"
        class="mt-4 text-sm text-gray-500"
      >
        沒有符合篩選條件的報名紀錄。
      </p>
    </div>
  </section>
</template>
