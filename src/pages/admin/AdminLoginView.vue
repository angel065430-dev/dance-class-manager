<script setup lang="ts">
/** 管理員登入頁（Email + Password，PHASE_0_AUDIT_REPORT.md 第 4.3.3 節）。 */
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const router = useRouter()
const { loginAdmin } = useAuth()

const email = ref('')
const password = ref('')
const submitting = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''
  submitting.value = true
  try {
    await loginAdmin(email.value, password.value)
    router.push('/admin/registrations')
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : '登入失敗'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <section class="mx-auto max-w-sm">
    <h1 class="text-xl font-bold text-gray-900">管理員登入</h1>

    <form class="mt-6 space-y-4" @submit.prevent="handleSubmit">
      <div>
        <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
        <input
          id="email"
          v-model="email"
          type="email"
          required
          class="mt-1 block w-full rounded border border-gray-300 px-3 py-2"
        />
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-gray-700">密碼</label>
        <input
          id="password"
          v-model="password"
          type="password"
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

    <p class="mt-4 text-xs text-gray-500">
      管理員帳號由既有管理員透過 Supabase Service Role 建立，本頁不提供自助註冊。
    </p>
  </section>
</template>
