import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders, internalStudentEmail, json, normalizeTaiwanPhone, sha256Hex } from '../_shared/security.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ success: false, error: 'method_not_allowed' }, 405)
  try {
    const body = await request.json()
    const phone = normalizeTaiwanPhone(body.phone)
    if (!phone || typeof body.pin !== 'string' || !/^\d{6}$/.test(body.pin))
      return json({ success: false, error: '手機號碼或 PIN 錯誤' }, 400)

    const url = Deno.env.get('SUPABASE_URL'); const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!url || !anonKey || !serviceKey) return json({ success: false, error: 'server_not_configured' }, 500)

    const phoneHash = await sha256Hex(phone)
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
    const { data: throttleRows, error: throttleError } = await admin.rpc('reserve_student_login_attempt', {
      p_phone_hash: phoneHash,
    })
    if (throttleError || !Array.isArray(throttleRows) || throttleRows.length !== 1)
      return json({ success: false, error: '登入安全檢查暫時無法完成，請稍後再試' }, 503)
    const throttle = throttleRows[0]
    if (!throttle.allowed)
      return json({ success: false, error: '嘗試次數過多，請 15 分鐘後再試或聯絡老師' }, 429)

    const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } })
    const email = await internalStudentEmail(phone)
    const { data, error } = await auth.auth.signInWithPassword({ email, password: body.pin })
    if (error || !data.session) {
      return json({ success: false, error: throttle.lock_on_failure ? '嘗試次數過多，請 15 分鐘後再試或聯絡老師' : '手機號碼或 PIN 錯誤' }, throttle.lock_on_failure ? 429 : 401)
    }

    const { error: clearError } = await admin.rpc('clear_student_login_failures', { p_phone_hash: phoneHash })
    if (clearError) {
      await auth.auth.signOut({ scope: 'global' })
      return json({ success: false, error: '登入安全確認失敗，請稍後再試' }, 503)
    }
    return json({ success: true, access_token: data.session.access_token, refresh_token: data.session.refresh_token })
  } catch { return json({ success: false, error: 'invalid_request' }, 400) }
})
