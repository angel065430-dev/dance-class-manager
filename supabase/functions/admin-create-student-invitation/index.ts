import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders, generateInvitationCode, json, normalizeTaiwanPhone, sha256Hex } from '../_shared/security.ts'

// Authorization is re-checked against user_roles in the function; gateway JWT
// verification alone is never treated as proof of the admin role.
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ success: false, error: 'method_not_allowed' }, 405)
  try {
    const url = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!url || !anonKey || !serviceKey) return json({ success: false, error: 'server_not_configured' }, 500)
    const authorization = request.headers.get('Authorization')
    if (!authorization) return json({ success: false, error: 'unauthorized' }, 401)

    const caller = createClient(url, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } })
    const { data: userData, error: userError } = await caller.auth.getUser()
    if (userError || !userData.user) return json({ success: false, error: 'unauthorized' }, 401)

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
    const { data: role, error: roleError } = await admin.from('user_roles').select('user_id').eq('user_id', userData.user.id).eq('role', 'admin').maybeSingle()
    if (roleError) return json({ success: false, error: 'authorization_check_failed' }, 503)
    if (!role) return json({ success: false, error: 'forbidden' }, 403)

    const body = await request.json()
    const phone = normalizeTaiwanPhone(body.phone)
    if (!phone) return json({ success: false, error: '請輸入正確的台灣手機號碼' }, 400)
    const { data: existing, error: profileError } = await admin.from('profiles').select('id').eq('phone', phone).maybeSingle()
    if (profileError) return json({ success: false, error: '帳號檢查失敗' }, 503)
    if (existing) return json({ success: false, error: '此手機已有帳號，請使用 PIN 重設流程' }, 409)

    const code = generateInvitationCode()
    const phoneHash = await sha256Hex(phone)
    const tokenHash = await sha256Hex(code)
    const expiresAt = new Date(Date.now() + 72 * 60 * 60_000).toISOString()
    const reason = typeof body.reason === 'string' ? body.reason : ''
    const { data: invitationId, error: invitationError } = await admin.rpc('admin_create_student_invitation', {
      p_actor_id: userData.user.id,
      p_phone_hash: phoneHash,
      p_token_hash: tokenHash,
      p_expires_at: expiresAt,
      p_reason: reason,
    })
    if (invitationError || !invitationId) return json({ success: false, error: '邀請建立失敗，未產生可用邀請碼' }, 500)
    return json({ success: true, invitation_code: code, expires_at: expiresAt })
  } catch {
    return json({ success: false, error: 'invalid_request' }, 400)
  }
})
