import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders, generateStrongPin, json, normalizeTaiwanPhone } from '../_shared/security.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ success: false, error: 'method_not_allowed' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !anonKey || !serviceKey) return json({ success: false, error: 'server_not_configured' }, 500)

  const authorization = request.headers.get('Authorization')
  if (!authorization) return json({ success: false, error: 'unauthorized' }, 401)

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  })
  const { data: userData, error: userError } = await caller.auth.getUser()
  if (userError || !userData.user) return json({ success: false, error: 'unauthorized' }, 401)

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
  const { data: role, error: roleError } = await admin.from('user_roles').select('user_id').eq('user_id', userData.user.id).eq('role', 'admin').maybeSingle()
  if (roleError) return json({ success: false, error: 'authorization_check_failed' }, 503)
  if (!role) return json({ success: false, error: 'forbidden' }, 403)

  try {
    const body = await request.json()
    const phone = normalizeTaiwanPhone(body.phone)
    if (!phone) return json({ success: false, error: '請輸入正確的台灣手機號碼' }, 400)

    const { data: profile, error: profileError } = await admin.from('profiles').select('id').eq('phone', phone).maybeSingle()
    if (profileError) return json({ success: false, error: '帳號查詢失敗' }, 503)
    if (!profile) return json({ success: false, error: '找不到此學生帳號' }, 404)

    const reason = typeof body.reason === 'string' ? body.reason.trim().slice(0, 200) : ''
    if (!reason) return json({ success: false, error: '請填寫 PIN 重設原因' }, 400)
    const { error: startedAuditError } = await admin.rpc('record_admin_pin_reset_event', {
      p_actor_id: userData.user.id,
      p_student_id: profile.id,
      p_action: 'student_pin_reset_started',
      p_reason: reason,
    })
    if (startedAuditError) return json({ success: false, error: '稽核紀錄失敗，PIN 未重設' }, 500)

    const pin = generateStrongPin()
    const { error: updateError } = await admin.auth.admin.updateUserById(profile.id, { password: pin })
    if (updateError) {
      const { error: failedAuditError } = await admin.rpc('record_admin_pin_reset_event', {
        p_actor_id: userData.user.id,
        p_student_id: profile.id,
        p_action: 'student_pin_reset_failed',
        p_reason: reason,
      })
      return json({ success: false, error: failedAuditError ? 'PIN 重設與失敗稽核皆未完成，請聯絡系統管理員' : 'PIN 重設失敗' }, 500)
    }

    const { error: completedAuditError } = await admin.rpc('record_admin_pin_reset_event', {
      p_actor_id: userData.user.id,
      p_student_id: profile.id,
      p_action: 'student_pin_reset_completed',
      p_reason: reason,
    })
    if (completedAuditError)
      return json({ success: false, error: 'PIN 已變更但完成稽核失敗；請立即再次重設，不要將本次 PIN 提供給學生' }, 500)

    return json({ success: true, pin })
  } catch {
    return json({ success: false, error: 'invalid_request' }, 400)
  }
})
