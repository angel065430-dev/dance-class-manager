<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { studentDisplayName } from '@/utils/studentNames'
import { fetchAdminStudentProfiles, type AdminStudentProfile } from '@/services/adminStudentProfiles'
import { adminCreateStudentInvitation, adminResetStudentPin } from '@/services/studentAccounts'

const students = ref<AdminStudentProfile[]>([])
const studentSearch = ref('')
const studentLoading = ref(false)
const studentError = ref('')
const selectedStudent = ref<AdminStudentProfile | null>(null)
const filteredStudents = computed(() => {
  const q = studentSearch.value.trim().toLowerCase()
  return students.value.filter(s => `${s.name ?? ''} ${s.line_display_name ?? ''} ${s.phone ?? ''}`.toLowerCase().includes(q))
})
async function loadStudents() {
  studentLoading.value = true
  studentError.value = ''
  try { students.value = await fetchAdminStudentProfiles() }
  catch (err) { studentError.value = err instanceof Error ? err.message : '學生資料載入失敗' }
  finally { studentLoading.value = false }
}
onMounted(loadStudents)

const phone = ref(''); const reason = ref(''); const submitting = ref(false)
const errorMessage = ref(''); const oneTimePin = ref('')
const invitePhone = ref(''); const inviteReason = ref(''); const inviteSubmitting = ref(false)
const inviteError = ref(''); const invitationCode = ref(''); const invitationExpiresAt = ref('')

async function resetPin() {
  errorMessage.value = ''; oneTimePin.value = ''
  if (!window.confirm('確定已核對學生身分，並要重設此帳號的 PIN？')) return
  submitting.value = true
  try {
    const result = await adminResetStudentPin(phone.value, reason.value)
    oneTimePin.value = result.pin; reason.value = ''
  }
  catch (error) { errorMessage.value = error instanceof Error ? error.message : 'PIN 重設失敗' }
  finally { submitting.value = false }
}

async function createInvitation() {
  inviteError.value = ''; invitationCode.value = ''; invitationExpiresAt.value = ''
  if (!window.confirm('確定已核對學生身分，並為此手機建立單次安全邀請碼？')) return
  inviteSubmitting.value = true
  try {
    const result = await adminCreateStudentInvitation(invitePhone.value, inviteReason.value)
    invitationCode.value = result.code; invitationExpiresAt.value = result.expiresAt; inviteReason.value = ''
  }
  catch (error) { inviteError.value = error instanceof Error ? error.message : '邀請建立失敗' }
  finally { inviteSubmitting.value = false }
}
</script>

<template>
  <section class="mx-auto max-w-4xl">
    <h1 class="text-xl font-bold text-gray-900">學生帳號協助</h1>
    <p class="mt-2 text-sm text-gray-600">學生第一次建立帳號前，請先核對本人身分並產生與其手機綁定的邀請碼。</p>
    <form class="mt-6 space-y-4 rounded border border-gray-200 bg-white p-5" @submit.prevent="createInvitation">
      <h2 class="font-semibold text-gray-900">建立學生安全邀請</h2>
      <div><label for="invite-phone" class="block text-sm font-medium text-gray-700">學生手機號碼</label><input id="invite-phone" v-model="invitePhone" type="tel" inputmode="numeric" required placeholder="0912345678" class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" /></div>
      <div><label for="invite-reason" class="block text-sm font-medium text-gray-700">核對方式／備註（選填）</label><input id="invite-reason" v-model="inviteReason" type="text" maxlength="200" class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" /></div>
      <p v-if="inviteError" class="text-sm text-red-600">{{ inviteError }}</p>
      <button type="submit" :disabled="inviteSubmitting" class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50">{{ inviteSubmitting ? '處理中...' : '建立邀請碼' }}</button>
    </form>
    <div v-if="invitationCode" class="mt-5 rounded border border-emerald-300 bg-emerald-50 p-5" role="status">
      <p class="font-semibold text-gray-900">單次安全邀請碼</p><p class="mt-2 font-mono text-2xl tracking-widest text-gray-900">{{ invitationCode }}</p>
      <p class="mt-2 text-sm text-emerald-800">限綁定手機使用，有效至 {{ new Date(invitationExpiresAt).toLocaleString('zh-TW') }}。原碼不會儲存在系統。</p>
      <button type="button" class="mt-3 text-sm underline" @click="invitationCode = ''; invitationExpiresAt = ''">我已記下，立即清除</button>
    </div>

    <h2 class="mt-8 font-semibold text-gray-900">重設學生 PIN</h2>
    <p class="mt-2 text-sm text-gray-600">請先透過 LINE 或現場核對學生身分。新 PIN 只顯示這一次，系統不會儲存。</p>
    <form class="mt-6 space-y-4 rounded border border-gray-200 bg-white p-5" @submit.prevent="resetPin">
      <div><label for="student-phone" class="block text-sm font-medium text-gray-700">學生手機號碼</label><input id="student-phone" v-model="phone" type="tel" inputmode="numeric" required placeholder="0912345678" class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" /></div>
      <div><label for="reset-reason" class="block text-sm font-medium text-gray-700">重設原因</label><input id="reset-reason" v-model="reason" type="text" maxlength="200" required class="mt-1 block w-full rounded border border-gray-300 px-3 py-2" /></div>
      <p v-if="errorMessage" class="text-sm text-red-600">{{ errorMessage }}</p>
      <button type="submit" :disabled="submitting" class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50">{{ submitting ? '處理中...' : '重設 PIN' }}</button>
    </form>
    <div v-if="oneTimePin" class="mt-5 rounded border border-amber-300 bg-amber-50 p-5" role="status">
      <p class="font-semibold text-gray-900">一次性新 PIN</p><p class="mt-2 font-mono text-3xl tracking-widest text-gray-900">{{ oneTimePin }}</p>
      <p class="mt-2 text-sm text-amber-800">請立即私下告知學生。離開或重新整理此頁後無法再次查詢。</p>
      <button type="button" class="mt-3 text-sm underline" @click="oneTimePin = ''">我已記下，立即清除</button>
    </div>
    <div class="mt-8 rounded border border-gray-200 bg-white p-5">
      <h2 class="font-semibold">學生名單</h2>
      <input v-model="studentSearch" type="search" placeholder="搜尋中文本名、LINE 顯示名字或手機" class="mt-3 w-full rounded border px-3 py-2" />
      <p v-if="studentLoading" class="mt-2 text-sm">載入中...</p>
      <p v-if="studentError" class="mt-2 text-sm text-red-600">{{ studentError }}</p>
      <div class="mt-3 max-h-80 overflow-y-auto">
        <button v-for="student in filteredStudents" :key="student.id" type="button" class="block w-full border-b py-3 text-left text-sm" @click="selectedStudent = student">
          <span class="font-medium">{{ studentDisplayName(student.name, student.line_display_name) }}</span>
          <span class="ml-2 text-gray-500">{{ student.phone ?? '—' }}</span>
        </button>
      </div>
      <div v-if="selectedStudent" class="mt-5 space-y-2 border-t pt-4 text-sm">
        <h3 class="font-medium">學生詳細資料</h3>
        <p>中文本名：{{ selectedStudent.name ?? '—' }}</p>
        <p>LINE 顯示名字：{{ selectedStudent.line_display_name ?? '—' }}</p>
        <p>手機：{{ selectedStudent.phone ?? '—' }}</p>
        <p class="break-all text-xs text-gray-500">學生 ID：{{ selectedStudent.id }}</p>
        <p class="text-xs text-gray-500">建立時間：{{ new Date(selectedStudent.created_at).toLocaleString('zh-TW') }}</p>
      </div>
    </div>
  </section>
</template>
