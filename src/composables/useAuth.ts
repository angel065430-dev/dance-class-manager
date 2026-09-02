import { ref, computed } from 'vue'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabaseClient'
import { normalizeTaiwanPhone } from '@/utils/phone'
import { validatePin } from '@/utils/pin'
import type { UserRoleName } from '@/types/database'

/**
 * 全域登入狀態（模組層級的 ref，所有呼叫 useAuth() 的元件共用同一份狀態）。
 *
 * 對應 AI_INSTRUCTIONS.md 第 10 節：Auth 只負責「你是誰」；「你能做什麼」
 * 由 roles + RLS 負責。這裡的 roles 只用於前端路由導引／UI 顯示的方便性，
 * 不是安全邊界——真正的存取控制一律由後端 RLS 強制執行。
 */
const session = ref<Session | null>(null)
const roles = ref<UserRoleName[]>([])
const initialized = ref(false)
const initPromise = ref<Promise<void> | null>(null)

async function loadRoles(userId: string): Promise<UserRoleName[]> {
  const { data, error } = await supabase.from('user_roles').select('role').eq('user_id', userId)
  if (error) {
    // 讀取角色失敗不應該讓整個登入流程掛掉；以最保守的「沒有角色」處理，
    // 畫面上會視同一般未授權使用者，真正的權限仍然由 RLS 把關。
    console.error('[useAuth] 讀取角色失敗', error)
    return []
  }
  return (data ?? []).map((r) => r.role as UserRoleName)
}

async function refreshSession() {
  const { data } = await supabase.auth.getSession()
  session.value = data.session
  roles.value = data.session ? await loadRoles(data.session.user.id) : []
}

supabase.auth.onAuthStateChange((_event, newSession) => {
  session.value = newSession
  if (newSession) {
    loadRoles(newSession.user.id).then((r) => {
      roles.value = r
    })
  } else {
    roles.value = []
  }
})

function ensureInitialized(): Promise<void> {
  if (!initPromise.value) {
    initPromise.value = refreshSession().then(() => {
      initialized.value = true
    })
  }
  return initPromise.value
}

export function useAuth() {
  const user = computed<User | null>(() => session.value?.user ?? null)
  const isLoggedIn = computed(() => !!session.value)
  const isStudent = computed(() => roles.value.includes('student'))
  const isAdmin = computed(() => roles.value.includes('admin'))

  /**
   * 學生註冊（Phone + PIN）。
   * 對應 PHASE_0_AUDIT_REPORT.md 第 4.3.1 節：PIN 即為 Supabase Auth 的
   * password 欄位，不會有任何明碼 PIN 存進自訂資料表。
   * profiles/user_roles 由資料庫 Trigger（handle_new_auth_user）自動建立，
   * 前端完全不自行寫入這兩張表。
   */
  async function signUpStudent(rawPhone: string, pin: string) {
    const phoneResult = normalizeTaiwanPhone(rawPhone)
    if (!phoneResult.ok) throw new Error(phoneResult.error)

    const pinResult = validatePin(pin)
    if (!pinResult.ok) throw new Error(pinResult.error)

    const { data, error } = await supabase.auth.signUp({
      phone: phoneResult.e164,
      password: pin,
    })
    if (error) throw error

    session.value = data.session
    if (data.session) {
      roles.value = await loadRoles(data.session.user.id)
    }
    return data
  }

  async function loginStudent(rawPhone: string, pin: string) {
    const phoneResult = normalizeTaiwanPhone(rawPhone)
    if (!phoneResult.ok) throw new Error(phoneResult.error)

    const { data, error } = await supabase.auth.signInWithPassword({
      phone: phoneResult.e164,
      password: pin,
    })
    if (error) throw error

    session.value = data.session
    roles.value = await loadRoles(data.user.id)
    return data
  }

  /** 管理員登入（Email + Password，PHASE_0_AUDIT_REPORT.md 第 4.3.3 節）。 */
  async function loginAdmin(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error

    session.value = data.session
    roles.value = await loadRoles(data.user.id)

    if (!roles.value.includes('admin')) {
      // UX 層級的提早提示（不是安全邊界）：這個帳號沒有 admin 角色，
      // 讓使用者立刻知道帳密正確但沒有管理員權限，而不是進了後台才發現
      // 什麼資料都看不到。真正的資料存取仍然由 RLS 強制。
      await supabase.auth.signOut()
      session.value = null
      roles.value = []
      throw new Error('此帳號沒有管理員權限')
    }

    return data
  }

  async function logout() {
    await supabase.auth.signOut()
    session.value = null
    roles.value = []
  }

  return {
    init: ensureInitialized,
    initialized,
    session,
    user,
    roles,
    isLoggedIn,
    isStudent,
    isAdmin,
    signUpStudent,
    loginStudent,
    loginAdmin,
    logout,
  }
}
