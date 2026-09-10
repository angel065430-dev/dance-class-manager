import { supabase } from '@/lib/supabaseClient'
import type { DanceClass, Term, Venue } from '@/types/database'
export interface CreateAdminClassInput {
  venue_id: string
  term_id: string
  name: string
  class_code?: string | null
  weekdays: number[]
  start_time: string
  end_time: string
  capacity: number
  business_mode: 'self_operated' | 'external_center'
  full_term_price: number
  single_session_price?: number | null
  default_base_makeup_capacity?: number
  is_open_for_registration?: boolean
  is_active?: boolean
}



export interface UpdateAdminClassInput {
  venue_id: string
  term_id: string
  name: string
  class_code?: string | null
  weekdays: number[]
  start_time: string
  end_time: string
  capacity: number
  business_mode: 'self_operated' | 'external_center'
  full_term_price: number
  single_session_price?: number | null
  default_base_makeup_capacity?: number
  is_open_for_registration: boolean
  is_active: boolean
}

export async function fetchAdminVenues(): Promise<Venue[]> {
  const { data, error } = await supabase
    .from('venues')
    .select('id, name, address, business_mode, is_active, is_public, created_at')
    .order('name', { ascending: true })

  if (error) throw error
  return data ?? []
}

export async function fetchAdminTerms(): Promise<Term[]> {
  const { data, error } = await supabase
    .from('terms')
    .select('id, venue_id, name, start_date, end_date, is_active')
    .order('start_date', { ascending: false })

  if (error) throw error
  return data ?? []
}

export async function fetchAdminClasses(): Promise<DanceClass[]> {
  const { data, error } = await supabase
    .from('classes')
    .select(`
      id,
      venue_id,
      term_id,
      name,
      class_code,
      weekdays,
      start_time,
      end_time,
      capacity,
      business_mode,
      full_term_price,
      single_session_price,
      default_base_makeup_capacity,
      is_open_for_registration,
      is_active
    `)
    .order('name', { ascending: true })

  if (error) throw error
  return data ?? []
}


export async function createAdminClass(input: CreateAdminClassInput): Promise<DanceClass> {
  const { data, error } = await supabase
    .from('classes')
    .insert({
      venue_id: input.venue_id,
      term_id: input.term_id,
      name: input.name.trim(),
      class_code: input.class_code?.trim() || null,
      weekdays: input.weekdays,
      start_time: input.start_time,
      end_time: input.end_time,
      capacity: input.capacity,
      business_mode: input.business_mode,
      full_term_price: input.full_term_price,
      single_session_price: input.single_session_price ?? null,
      default_base_makeup_capacity: input.default_base_makeup_capacity ?? 0,
      is_open_for_registration: input.is_open_for_registration ?? false,
      is_active: input.is_active ?? true,
    })
    .select(`
      id,
      venue_id,
      term_id,
      name,
      class_code,
      weekdays,
      start_time,
      end_time,
      capacity,
      business_mode,
      full_term_price,
      single_session_price,
      default_base_makeup_capacity,
      is_open_for_registration,
      is_active
    `)
    .single()

  if (error) throw error
  return data
}




export async function updateAdminClass(
  id: string,
  input: UpdateAdminClassInput,
): Promise<DanceClass> {
  const { data, error } = await supabase
    .from('classes')
    .update({
      venue_id: input.venue_id,
      term_id: input.term_id,
      name: input.name.trim(),
      class_code: input.class_code?.trim() || null,
      weekdays: input.weekdays,
      start_time: input.start_time,
      end_time: input.end_time,
      capacity: input.capacity,
      business_mode: input.business_mode,
      full_term_price: input.full_term_price,
      single_session_price: input.single_session_price ?? null,
      default_base_makeup_capacity: input.default_base_makeup_capacity ?? 0,
      is_open_for_registration: input.is_open_for_registration,
      is_active: input.is_active,
    })
    .eq('id', id)
    .select(`
      id,
      venue_id,
      term_id,
      name,
      class_code,
      weekdays,
      start_time,
      end_time,
      capacity,
      business_mode,
      full_term_price,
      single_session_price,
      default_base_makeup_capacity,
      is_open_for_registration,
      is_active
    `)
    .single()

  if (error) throw error
  return data
}
