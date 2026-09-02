import { supabase } from '@/lib/supabaseClient'
import type { RegistrationWithClass, SubmitRegistrationsResult } from '@/types/database'

/** 供前端產生一次性的 idempotency key（REGISTRATION_MVP_PLAN.md 第 C 節）。 */
export function generateIdempotencyKey(): string {
  return crypto.randomUUID()
}

/**
 * 一次提交一堂或多堂期課報名。全部成功或全部失敗（見
 * rpc_submit_full_term_registrations 的 migration 註解與
 * REGISTRATION_MVP_PLAN.md 第 C 節）。
 */
export async function submitFullTermRegistrations(
  classIds: string[],
  idempotencyKey: string,
): Promise<SubmitRegistrationsResult> {
  const { data, error } = await supabase.rpc('rpc_submit_full_term_registrations', {
    p_class_ids: classIds,
    p_idempotency_key: idempotencyKey,
  })
  if (error) throw error
  return data as SubmitRegistrationsResult
}

/** 學生「我的報名」：RLS 已限制只能看到自己的列，這裡不需要再傳 student_id。 */
export async function fetchMyRegistrations(): Promise<RegistrationWithClass[]> {
  const { data, error } = await supabase
    .from('registrations')
    .select(
      `
      id, student_id, class_id, term_id, order_id, class_session_id,
      registration_type, status, created_at, cancelled_at, cancelled_reason,
      classes ( name, venues ( name ), terms ( name ) )
    `,
    )
    .order('created_at', { ascending: false })

  if (error) throw error

  return (data ?? []).map((row) => {
    const cls = Array.isArray(row.classes) ? row.classes[0] : row.classes
    const venue = cls ? (Array.isArray(cls.venues) ? cls.venues[0] : cls.venues) : undefined
    const term = cls ? (Array.isArray(cls.terms) ? cls.terms[0] : cls.terms) : undefined

    return {
      id: row.id,
      student_id: row.student_id,
      class_id: row.class_id,
      term_id: row.term_id,
      order_id: row.order_id,
      class_session_id: row.class_session_id,
      registration_type: row.registration_type,
      status: row.status,
      created_at: row.created_at,
      cancelled_at: row.cancelled_at,
      cancelled_reason: row.cancelled_reason,
      class_name: cls?.name ?? '',
      venue_name: venue?.name ?? '',
      term_name: term?.name ?? '',
    } satisfies RegistrationWithClass
  })
}

/**
 * Admin 報名清單（唯讀）。RLS 的 is_admin() 會允許看到所有學生的列；
 * 這裡額外 join profiles 取得學生姓名/手機供後台顯示。
 */
export async function fetchAllRegistrationsForAdmin(): Promise<
  Array<RegistrationWithClass & { student_name: string | null; student_phone: string | null }>
> {
  const { data, error } = await supabase
    .from('registrations')
    .select(
      `
      id, student_id, class_id, term_id, order_id, class_session_id,
      registration_type, status, created_at, cancelled_at, cancelled_reason,
      classes ( name, venues ( name ), terms ( name ) ),
      profiles ( name, phone )
    `,
    )
    .order('created_at', { ascending: false })

  if (error) throw error

  return (data ?? []).map((row) => {
    const cls = Array.isArray(row.classes) ? row.classes[0] : row.classes
    const venue = cls ? (Array.isArray(cls.venues) ? cls.venues[0] : cls.venues) : undefined
    const term = cls ? (Array.isArray(cls.terms) ? cls.terms[0] : cls.terms) : undefined
    const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles

    return {
      id: row.id,
      student_id: row.student_id,
      class_id: row.class_id,
      term_id: row.term_id,
      order_id: row.order_id,
      class_session_id: row.class_session_id,
      registration_type: row.registration_type,
      status: row.status,
      created_at: row.created_at,
      cancelled_at: row.cancelled_at,
      cancelled_reason: row.cancelled_reason,
      class_name: cls?.name ?? '',
      venue_name: venue?.name ?? '',
      term_name: term?.name ?? '',
      student_name: profile?.name ?? null,
      student_phone: profile?.phone ?? null,
    }
  })
}
