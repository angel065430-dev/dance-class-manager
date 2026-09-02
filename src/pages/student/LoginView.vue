<script setup lang="ts">
/** 學生登入頁（Phone + PIN）。 */
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const router = useRouter()
const { loginStudent } = useAuth()

const phone = ref('')
const pin = ref('')
const submitting = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''
  submitting.value = true
  try {
    await loginStudent(phone.value, pin.value)
    router.push('/courses')
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '登入失敗，請確認手機號碼與 PIN'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <section class="mx-auto max-w-sm">
    <h1 class="text-xl font-bold text-gray-900">學生登入</h1>

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
        <label for="pin" class="block text-sm font-medium text-gray-700">PIN</label>
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

      <p v-if="errorMessage" class="text-sm text-red-600">{{ errorMessage }}</p>

      <button
        type="submit"
        :disabled="submitting"
        class="w-full rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
      >
        {{ submitting ? '登入中...' : '登入' }}
      </button>
    </form>

    <p class="mt-4 text-sm text-gray-600">
      忘記 PIN？第一版由管理員協助重設，請透過 LINE 或現場告知老師。
    </p>
    <p class="mt-2 text-sm text-gray-600">
      還沒有帳號？
      <RouterLink to="/register" class="text-gray-900 underline">註冊</RouterLink>
    </p>
  </section>
</template>
