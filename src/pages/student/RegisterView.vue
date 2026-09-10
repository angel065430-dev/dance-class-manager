<script setup lang="ts">
/**
 * 學生註冊頁（Phone + PIN，PHASE_0_AUDIT_REPORT.md 第 4.3.1-4.3.2 節）。
 *
 * 前端先提供即時提示，create-student-account Edge Function 會再次強制驗證。
 */
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { normalizeStudentName, normalizeLineDisplayName } from '@/utils/studentNames'
import { validatePin } from '@/utils/pin'

const router = useRouter()
const { signUpStudent } = useAuth()

const name = ref('')
const lineDisplayName = ref('')
const phone = ref('')
const invitationCode = ref('')
const pin = ref('')
const pinConfirm = ref('')
const submitting = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''

  let legalName: string
  let lineName: string | null
  try {
    legalName = normalizeStudentName(name.value)
    lineName = normalizeLineDisplayName(lineDisplayName.value)
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '姓名格式不正確'
    return
  }

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
    await signUpStudent(phone.value, pin.value, invitationCode.value, legalName, lineName)
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
    <p class="mt-1 text-sm text-gray-600">請使用老師提供、與手機號碼綁定的邀請碼建立帳號；系統不會發送簡訊。</p>

    <form class="mt-6 space-y-4" @submit.prevent="handleSubmit">
      <div>
        <label for="legal-name" class="block text-sm font-medium text-gray-700">中文本名（必填）</label>
        <input id="legal-name" v-model="name" type="text" autocomplete="name" maxlength="80" required class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" />
      </div>
      <div>
        <label for="line-display-name" class="block text-sm font-medium text-gray-700">LINE 顯示名字（選填）</label>
        <input id="line-display-name" v-model="lineDisplayName" type="text" maxlength="100" class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" />
        <p class="mt-1 text-xs text-gray-500">請填寫你在 LINE 上使用的名字，方便老師辨識，不需連結 LINE 帳號。</p>
      </div>
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
        <label for="invitation-code" class="block text-sm font-medium text-gray-700">安全邀請碼</label>
        <input
          id="invitation-code"
          v-model="invitationCode"
          type="text"
          autocomplete="one-time-code"
          maxlength="14"
          required
          class="mt-1 block w-full rounded border border-gray-300 px-3 py-2 uppercase"
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
