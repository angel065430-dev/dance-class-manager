import { supabase } from '@/lib/supabaseClient'
import { normalizeTaiwanPhone } from '@/utils/phone'
import { functionErrorMessage } from '@/utils/functionErrors'

interface ResetPinResult { success: boolean; pin?: string; error?: string }
interface InvitationResult { success: boolean; invitation_code?: string; expires_at?: string; error?: string }

export async function adminResetStudentPin(rawPhone: string, reason: string): Promise<{ pin: string }> {
  const normalized = normalizeTaiwanPhone(rawPhone)
  if (!normalized.ok) throw new Error(normalized.error)
  const { data, error } = await supabase.functions.invoke<ResetPinResult>('admin-reset-student-pin', {
    body: { phone: normalized.e164, reason },
  })
  if (error) throw new Error(await functionErrorMessage(error, 'PIN 重設失敗'))
  if (!data?.success || !data.pin) throw new Error(data?.error ?? 'PIN 重設失敗')
  return { pin: data.pin }
}

export async function adminCreateStudentInvitation(rawPhone: string, reason: string): Promise<{ code: string; expiresAt: string }> {
  const normalized = normalizeTaiwanPhone(rawPhone)
  if (!normalized.ok) throw new Error(normalized.error)
  const { data, error } = await supabase.functions.invoke<InvitationResult>('admin-create-student-invitation', {
    body: { phone: normalized.e164, reason },
  })
  if (error) throw new Error(await functionErrorMessage(error, '邀請建立失敗'))
  if (!data?.success || !data.invitation_code || !data.expires_at)
    throw new Error(data?.error ?? '邀請建立失敗')
  return { code: data.invitation_code, expiresAt: data.expires_at }
}
