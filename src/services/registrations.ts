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

/**
 * 學生提交付款資料。
 * 銀行轉帳需提供帳號末五碼；LINE Pay 不需末五碼。
 * 真正的付款完成狀態仍只能由管理員確認。
 */
export async function submitPaymentReference(
  orderId: string,
  paymentMethod: 'bank_transfer' | 'line_pay',
  paymentReference: string | null = null,
): Promise<void> {
  const { error } = await supabase.rpc('rpc_submit_payment_reference', {
    p_order_id: orderId,
    p_payment_method: paymentMethod,
    p_payment_reference: paymentReference,
  })

  if (error) throw error
}

/** 學生「我的報名」：RLS 已限制只能看到自己的列，這裡不需要再傳 student_id。 */
export async function fetchMyRegistrations(): Promise<RegistrationWithClass[]> {
  const { data, error } = await supabase
    .from('registrations')
    .select(
      `
      id, student_id, class_id, term_id, order_id, class_session_id,
      registration_type, status, created_at, cancelled_at, cancelled_reason,
      classes ( name, venues ( id, name ), terms ( name ) ),
      orders ( payment_status, payment_method, payment_reference, paid_at, total_amount )
    `,
    )
    .order('created_at', { ascending: false })

  if (error) throw error

  return (data ?? []).map((row) => {
    const cls = Array.isArray(row.classes) ? row.classes[0] : row.classes
    const venue = cls ? (Array.isArray(cls.venues) ? cls.venues[0] : cls.venues) : undefined
    const term = cls ? (Array.isArray(cls.terms) ? cls.terms[0] : cls.terms) : undefined
    const order = Array.isArray(row.orders) ? row.orders[0] : row.orders

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
      venue_id: venue?.id ?? '',
      venue_name: venue?.name ?? '',
      term_name: term?.name ?? '',
      total_amount: Number(order?.total_amount ?? 0),
      payment_status: order?.payment_status ?? 'pending',
      payment_method: order?.payment_method ?? null,
      payment_reference: order?.payment_reference ?? null,
      paid_at: order?.paid_at ?? null,
    } satisfies RegistrationWithClass
  })
}

/**
 * Admin 報名清單。RLS 的 is_admin() 會允許看到所有學生的列；
 * 這裡額外 join profiles 取得學生姓名/手機供後台顯示。
 */
export async function fetchAllRegistrationsForAdmin(): Promise<
  Array<RegistrationWithClass & { student_name: string | null; student_phone: string | null; student_line_display_name: string | null }>
> {
  const { data, error } = await supabase
    .from('registrations')
    .select(
      `
      id, student_id, class_id, term_id, order_id, class_session_id,
      registration_type, status, created_at, cancelled_at, cancelled_reason,
      classes ( name, venues ( id, name ), terms ( name ) ),
      orders ( payment_status, payment_method, payment_reference, paid_at, total_amount ),
      profiles ( name, phone, line_display_name )
    `,
    )
    .order('created_at', { ascending: false })

  if (error) throw error

  return (data ?? []).map((row) => {
    const cls = Array.isArray(row.classes) ? row.classes[0] : row.classes
    const venue = cls ? (Array.isArray(cls.venues) ? cls.venues[0] : cls.venues) : undefined
    const term = cls ? (Array.isArray(cls.terms) ? cls.terms[0] : cls.terms) : undefined
    const order = Array.isArray(row.orders) ? row.orders[0] : row.orders
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
      venue_id: venue?.id ?? '',
      venue_name: venue?.name ?? '',
      term_name: term?.name ?? '',
      total_amount: Number(order?.total_amount ?? 0),
      payment_status: order?.payment_status ?? 'pending',
      payment_method: order?.payment_method ?? null,
      payment_reference: order?.payment_reference ?? null,
      paid_at: order?.paid_at ?? null,
      student_name: profile?.name ?? null,
      student_phone: profile?.phone ?? null,
      student_line_display_name: profile?.line_display_name ?? null,
    }
  })
}

/**
 * Admin 確認訂單已收款。
 * 權限由 rpc_admin_mark_order_paid 伺服器端再次檢查，
 * 一般學生無法自行把付款狀態改成 paid。
 */
export async function adminMarkOrderPaid(orderId: string): Promise<void> {
  const { error } = await supabase.rpc('rpc_admin_mark_order_paid', {
    p_order_id: orderId,
  })

  if (error) throw error
}
