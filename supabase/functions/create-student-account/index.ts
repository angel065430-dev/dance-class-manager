import { normalizeStudentName, normalizeLineDisplayName } from '../_shared/studentNames.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders, internalStudentEmail, isStrongPin, json, normalizeTaiwanPhone, sha256Hex } from '../_shared/security.ts'

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ success: false, error: 'method_not_allowed' }, 405)

  try {
    const body = await request.json()
    let name: string
    let lineDisplayName: string | null
    try {
      name = normalizeStudentName(body.name)
      lineDisplayName = normalizeLineDisplayName(body.line_display_name)
    } catch (error) {
      return json({ success: false, error: error instanceof Error ? error.message : '姓名格式不正確' }, 400)
    }
    const phone = normalizeTaiwanPhone(body.phone)
    if (!phone) return json({ success: false, error: '請輸入正確的台灣手機號碼' }, 400)
    if (!isStrongPin(body.pin)) return json({ success: false, error: 'PIN 必須為 6 位數字，且不可全部相同或連號' }, 400)

    const url = Deno.env.get('SUPABASE_URL')
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!url || !serviceKey) return json({ success: false, error: 'server_not_configured' }, 500)

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } })
    const source = request.headers.get('cf-connecting-ip') ?? request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
    const clientHash = await sha256Hex(source)
    const { data: throttleRows, error: throttleError } = await admin.rpc('consume_student_signup_attempt', {
      p_client_hash: clientHash,
    })
    if (throttleError || !Array.isArray(throttleRows) || throttleRows.length !== 1)
      return json({ success: false, error: '帳號安全檢查暫時無法完成，請稍後再試' }, 503)
    if (!throttleRows[0].allowed)
      return json({ success: false, error: '建立帳號次數過多，請稍後再試或聯絡老師' }, 429)

    const email = await internalStudentEmail(phone)
    const { data: created, error } = await admin.auth.admin.createUser({
      email,
      password: body.pin,
      email_confirm: true,
      user_metadata: { account_source: 'student_self_service_no_sms', login_kind: 'phone_pin' },
    })

    if (error) {
      const duplicate = /already|registered|exists/i.test(error.message)
      return json({ success: false, error: duplicate ? '此號碼無法建立或已經有帳號，請嘗試登入或聯絡老師' : '帳號建立失敗' }, duplicate ? 409 : 400)
    }

    const userId = created.user?.id
    if (!userId) {
      return json({ success: false, error: '帳號建立失敗' }, 500)
    }

    const { data: updatedProfiles, error: profileError } = await admin.from('profiles').update({ phone, name, line_display_name: lineDisplayName }).eq('id', userId).select('id')
    const { error: roleError } = await admin.from('user_roles').insert({ user_id: userId, role: 'student' })
    if (profileError || updatedProfiles?.length !== 1 || roleError) {
      await admin.auth.admin.deleteUser(userId)
      return json({ success: false, error: '帳號資料建立失敗，請稍後再試' }, 500)
    }



    return json({ success: true }, 201)
  } catch {
    return json({ success: false, error: 'invalid_request' }, 400)
  }
})
