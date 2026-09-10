import { supabase } from '@/lib/supabaseClient'
import type { ClassWithAvailability } from '@/types/database'

/**
 * 公開課程瀏覽（Registration MVP，只包含期課／自營教室，任何人可查詢）。
 *
 * 名額顯示只供參考（AI_INSTRUCTIONS.md 第 20 節），真正的名額把關在
 * rpc_submit_full_term_registrations() 內完成，這裡的 remaining_seats
 * 只是提升瀏覽體驗用。
 */
export async function fetchOpenClasses(): Promise<ClassWithAvailability[]> {
  const { data, error } = await supabase
    .from('classes')
    .select(
      `
      id, venue_id, term_id, name, class_code, weekdays, start_time, end_time, capacity,
      business_mode, full_term_price, single_session_price,
      default_base_makeup_capacity, is_open_for_registration, is_active,
      venues ( name ),
      terms ( name )
    `,
    )
    .eq('is_active', true)
    .eq('is_open_for_registration', true)
    .order('name', { ascending: true })

  if (error) throw error

  const rows = data ?? []

  const withSeats = await Promise.all(
    rows.map(async (row) => {
      const { data: seats, error: seatsError } = await supabase.rpc('fn_class_remaining_seats', {
        p_class_id: row.id,
      })
      if (seatsError) {
        console.error('[fetchOpenClasses] fn_class_remaining_seats 失敗', seatsError)
      }

      // Supabase JS 對一對一關聯的型別預設是陣列，實際上這裡一定是單一物件。
      const venue = Array.isArray(row.venues) ? row.venues[0] : row.venues
      const term = Array.isArray(row.terms) ? row.terms[0] : row.terms

      const result: ClassWithAvailability = {
        id: row.id,
        venue_id: row.venue_id,
        term_id: row.term_id,
        name: row.name,
        class_code: row.class_code,
        weekdays: row.weekdays,
        start_time: row.start_time,
        end_time: row.end_time,
        capacity: row.capacity,
        business_mode: row.business_mode,
        full_term_price: row.full_term_price,
        single_session_price: row.single_session_price,
        default_base_makeup_capacity: row.default_base_makeup_capacity,
        is_open_for_registration: row.is_open_for_registration,
        is_active: row.is_active,
        venue_name: venue?.name ?? '',
        term_name: term?.name ?? '',
        remaining_seats: seatsError ? null : (seats as number | null),
      }
      return result
    }),
  )

  return withSeats
}
