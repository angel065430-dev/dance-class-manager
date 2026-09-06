import { supabase } from '@/lib/supabaseClient'
import type { Term, Venue } from '@/types/database'

export interface CreateAdminVenueInput {
  name: string
  address?: string | null
  business_mode: 'self_operated' | 'external_center'
  is_active: boolean
  is_public: boolean
}

export interface CreateAdminTermInput {
  venue_id: string
  name: string
  start_date: string
  end_date: string
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

export async function createAdminVenue(
  input: CreateAdminVenueInput,
): Promise<Venue> {
  const { data, error } = await supabase
    .from('venues')
    .insert({
      name: input.name.trim(),
      address: input.address?.trim() || null,
      business_mode: input.business_mode,
      is_active: input.is_active,
      is_public: input.is_public,
    })
    .select('id, name, address, business_mode, is_active, is_public, created_at')
    .single()

  if (error) throw error
  return data
}

export async function fetchAdminTerms(): Promise<Term[]> {
  const { data, error } = await supabase
    .from('terms')
    .select('id, venue_id, name, start_date, end_date, is_active')
    .order('start_date', { ascending: false })

  if (error) throw error
  return data ?? []
}

export async function createAdminTerm(
  input: CreateAdminTermInput,
): Promise<Term> {
  const { data, error } = await supabase
    .from('terms')
    .insert({
      venue_id: input.venue_id,
      name: input.name.trim(),
      start_date: input.start_date,
      end_date: input.end_date,
      is_active: input.is_active,
    })
    .select('id, venue_id, name, start_date, end_date, is_active')
    .single()

  if (error) throw error
  return data
}
