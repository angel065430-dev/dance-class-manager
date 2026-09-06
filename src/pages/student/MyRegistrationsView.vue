<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  fetchMyRegistrations,
  submitPaymentReference,
} from '@/services/registrations'
import {
  fetchVenuePaymentSettings,
  type VenuePaymentSettings,
} from '@/services/paymentSettings'
import type { RegistrationWithClass } from '@/types/database'

const registrations = ref<RegistrationWithClass[]>([])
const paymentSettingsByVenue = ref<Record<string, VenuePaymentSettings | null>>({})
const loading = ref(true)
const errorMessage = ref('')

const paymentReferenceByOrder = ref<Record<string, string>>({})
const submittingOrderId = ref<string | null>(null)
const successMessageByOrder = ref<Record<string, string>>({})
const paymentErrorByOrder = ref<Record<string, string>>({})

const STATUS_TEXT: Record<string, string> = {
  active: '有效',
  cancelled: '已取消',
}

const PAYMENT_STATUS_TEXT: Record<string, string> = {
  pending: '待付款',
  paid: '已付款',
}

function formatCurrency(amount: number) {
  return new Intl.NumberFormat('zh-TW', {
    style: 'currency',
    currency: 'TWD',
    maximumFractionDigits: 0,
  }).format(amount)
}

function formatPaymentMethod(method: RegistrationWithClass['payment_method']) {
  if (method === 'bank_transfer') return '銀行轉帳'
  if (method === 'line_pay') return 'LINE Pay'
  return ''
}

async function loadData() {
  loading.value = true
  errorMessage.value = ''

  try {
    const rows = await fetchMyRegistrations()
    registrations.value = rows

    const venueIds = [...new Set(rows.map((row) => row.venue_id).filter(Boolean))]

    const entries = await Promise.all(
      venueIds.map(async (venueId) => {
        try {
          const settings = await fetchVenuePaymentSettings(venueId)
          return [venueId, settings] as const
        } catch {
          return [venueId, null] as const
        }
      }),
    )

    paymentSettingsByVenue.value = Object.fromEntries(entries)

    for (const reg of rows) {
      if (reg.payment_reference) {
        paymentReferenceByOrder.value[reg.order_id] = reg.payment_reference
      }
    }
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '報名紀錄載入失敗'
  } finally {
    loading.value = false
  }
}

async function submitBankTransfer(reg: RegistrationWithClass) {
  const reference = (paymentReferenceByOrder.value[reg.order_id] ?? '').trim()

  successMessageByOrder.value[reg.order_id] = ''
  paymentErrorByOrder.value[reg.order_id] = ''

  if (!/^\d{5}$/.test(reference)) {
    paymentErrorByOrder.value[reg.order_id] = '請輸入匯款帳號末五碼。'
    return
  }

  submittingOrderId.value = reg.order_id

  try {
    await submitPaymentReference(reg.order_id, 'bank_transfer', reference)
    successMessageByOrder.value[reg.order_id] = '付款資料已提交，待老師確認收款。'
    await loadData()
  } catch (err) {
    paymentErrorByOrder.value[reg.order_id] =
      err instanceof Error ? err.message : '付款資料提交失敗'
  } finally {
    submittingOrderId.value = null
  }
}

async function submitLinePay(reg: RegistrationWithClass) {
  successMessageByOrder.value[reg.order_id] = ''
  paymentErrorByOrder.value[reg.order_id] = ''
  submittingOrderId.value = reg.order_id

  try {
    await submitPaymentReference(reg.order_id, 'line_pay', null)
    successMessageByOrder.value[reg.order_id] = '已登記 LINE Pay，待老師確認收款。'
    await loadData()
  } catch (err) {
    paymentErrorByOrder.value[reg.order_id] =
      err instanceof Error ? err.message : '付款資料提交失敗'
  } finally {
    submittingOrderId.value = null
  }
}

onMounted(loadData)
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

    <ul v-if="registrations.length > 0" class="mt-4 space-y-4">
      <li
        v-for="reg in registrations"
        :key="reg.id"
        class="rounded border border-gray-200 bg-white p-4"
      >
        <p class="font-medium text-gray-900">{{ reg.class_name }}</p>

        <p class="text-sm text-gray-500">
          {{ reg.venue_name }} ・ {{ reg.term_name }}
        </p>

        <p class="text-sm text-gray-500">
          報名時間：{{ new Date(reg.created_at).toLocaleString('zh-TW') }}
        </p>

        <p
          class="text-sm"
          :class="reg.status === 'active' ? 'text-green-700' : 'text-gray-400'"
        >
          報名狀態：{{ STATUS_TEXT[reg.status] ?? reg.status }}
        </p>

        <p
          class="mt-1 text-sm font-medium"
          :class="reg.payment_status === 'paid' ? 'text-green-700' : 'text-amber-600'"
        >
          付款狀態：{{ PAYMENT_STATUS_TEXT[reg.payment_status] ?? reg.payment_status }}
        </p>

        <p class="mt-1 text-sm font-semibold text-gray-900">
          應付金額：{{ formatCurrency(reg.total_amount) }}
        </p>

        <div
          v-if="reg.payment_status === 'paid'"
          class="mt-3 rounded bg-green-50 p-3 text-sm text-green-800"
        >
          已確認收款
          <span v-if="reg.payment_method">
            ・{{ formatPaymentMethod(reg.payment_method) }}
          </span>
        </div>

        <div
          v-else
          class="mt-4 rounded border border-amber-200 bg-amber-50 p-4"
        >
          <template v-if="paymentSettingsByVenue[reg.venue_id]">
            <p class="font-semibold text-gray-900">付款方式</p>

            <div class="mt-3">
              <p class="font-medium text-gray-900">銀行轉帳</p>

              <p class="mt-1 text-sm text-gray-700">
                {{ paymentSettingsByVenue[reg.venue_id]?.bank_name }}
                <span v-if="paymentSettingsByVenue[reg.venue_id]?.bank_code">
                  （{{ paymentSettingsByVenue[reg.venue_id]?.bank_code }}）
                </span>
              </p>

              <p class="text-sm text-gray-700">
                帳號：{{ paymentSettingsByVenue[reg.venue_id]?.bank_account }}
              </p>

              <label class="mt-3 block text-sm font-medium text-gray-700">
                匯款帳號末五碼
              </label>

              <div class="mt-1 flex gap-2">
                <input
                  v-model="paymentReferenceByOrder[reg.order_id]"
                  inputmode="numeric"
                  maxlength="5"
                  placeholder="例如：12345"
                  class="min-w-0 flex-1 rounded border border-gray-300 px-3 py-2 text-sm"
                />

                <button
                  type="button"
                  class="rounded bg-gray-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
                  :disabled="submittingOrderId === reg.order_id"
                  @click="submitBankTransfer(reg)"
                >
                  提交
                </button>
              </div>

              <p
                v-if="
                  reg.payment_method === 'bank_transfer' &&
                  reg.payment_reference
                "
                class="mt-2 text-xs text-amber-700"
              >
                已提交末五碼 {{ reg.payment_reference }}，待老師確認。
              </p>
            </div>

            <div class="mt-5 border-t border-amber-200 pt-4">
              <p class="font-medium text-gray-900">LINE Pay</p>

              <p class="mt-1 text-sm text-gray-700">
                {{ paymentSettingsByVenue[reg.venue_id]?.line_pay_instructions }}
              </p>

              <button
                type="button"
                class="mt-3 rounded border border-gray-900 px-4 py-2 text-sm font-medium text-gray-900 disabled:opacity-50"
                :disabled="submittingOrderId === reg.order_id"
                @click="submitLinePay(reg)"
              >
                登記使用 LINE Pay
              </button>

              <p
                v-if="reg.payment_method === 'line_pay'"
                class="mt-2 text-xs text-amber-700"
              >
                已登記 LINE Pay，待老師確認收款。
              </p>
            </div>

            <p
              v-if="successMessageByOrder[reg.order_id]"
              class="mt-3 text-sm text-green-700"
            >
              {{ successMessageByOrder[reg.order_id] }}
            </p>

            <p
              v-if="paymentErrorByOrder[reg.order_id]"
              class="mt-3 text-sm text-red-600"
            >
              {{ paymentErrorByOrder[reg.order_id] }}
            </p>
          </template>

          <p v-else class="text-sm text-red-600">
            付款資訊尚未設定，請聯絡老師。
          </p>
        </div>
      </li>
    </ul>
  </section>
</template>
