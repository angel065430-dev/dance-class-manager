<script setup lang="ts">
/**
 * 學生註冊頁（Phone + PIN，PHASE_0_AUDIT_REPORT.md 第 4.3.1-4.3.2 節）。
 *
 * 前端封鎖弱 PIN 只是第一道防線，不是伺服器端強制（見 src/utils/pin.ts
 * 註解與 REGISTRATION_MVP_PLAN.md「明確延後的項目」）。
 */
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { validatePin } from '@/utils/pin'

const router = useRouter()
const { signUpStudent } = useAuth()

const phone = ref('')
const pin = ref('')
const pinConfirm = ref('')
const submitting = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''

  if (pin.value !== pinConfirm.value) {
    errorMessage.value = '兩次輸入的 PIN 不一致'
    return
  }

  const pinCheck = validatePin(pin.value)
  if (!pinCheck.ok) {
    errorMessage.value = pinCheck.error
    return
  }

  submitting.value = true
  try {
    await signUpStudent(phone.value, pin.value)
    router.push('/courses')
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '註冊失敗，請稍後再試'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <section class="mx-auto max-w-sm">
    <h1 class="text-xl font-bold text-gray-900">學生註冊</h1>
    <p class="mt-1 text-sm text-gray-600">使用手機號碼與 6 位數 PIN 建立帳號。</p>

    <form class="mt-6 space-y-4" @submit.prevent="handleSubmit">
      <div>
        <label for="phone" class="block text-sm font-medium text-gray-700">手機號碼</label>
        <input
          id="phone"
          v-model="phone"
          type="tel"
          inputmode="numeric"
          placeholder="0912345678"
          required
          class="mt-1 block w-full rounded border border-gray-300 px-3 py-2"
        />
      </div>

      <div>
        <label for="pin" class="block text-sm font-medium text-gray-700">設定 6 位數 PIN</label>
        <input
          id="pin"
          v-model="pin"
          type="password"
          inputmode="numeric"
          maxlength="6"
          required
          class="mt-1 block w-full rounded border border-gray-300 px-3 py-2"
        />
      </div>

      <div>
        <label for="pin-confirm" class="block text-sm font-medium text-gray-700"
          >再次輸入 PIN</label
        >
        <input
          id="pin-confirm"
          v-model="pinConfirm"
          type="password"
          inputmode="numeric"
          maxlength="6"
          required
          class="mt-1 block w-full rounded border border-gray-300 px-3 py-2"
        />
      </div>

      <p v-if="errorMessage" class="text-sm text-red-600">{{ errorMessage }}</p>

      <button
        type="submit"
        :disabled="submitting"
        class="w-full rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
      >
        {{ submitting ? '註冊中...' : '註冊' }}
      </button>
    </form>

    <p class="mt-4 text-sm text-gray-600">
      已經有帳號？
      <RouterLink to="/login" class="text-gray-900 underline">登入</RouterLink>
    </p>
  </section>
</template>
