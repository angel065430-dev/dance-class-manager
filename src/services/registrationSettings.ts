import { supabase } from '@/lib/supabaseClient'

export interface RegistrationSettings {
  enabled: boolean
  min_full_term_classes: number
  full_term_discount_percent: number
}

export async function fetchRegistrationSettings(): Promise<RegistrationSettings> {
  const { data, error } = await supabase
    .from('registration_settings')
    .select('enabled, min_full_term_classes, full_term_discount_percent')
    .eq('id', 1)
    .single()
  if (error) throw error
  return { ...data, full_term_discount_percent: Number(data.full_term_discount_percent) }
}

export async function updateRegistrationSettings(input: RegistrationSettings): Promise<RegistrationSettings> {
  const { data, error } = await supabase
    .from('registration_settings')
    .update({ ...input, updated_at: new Date().toISOString() })
    .eq('id', 1)
    .select('enabled, min_full_term_classes, full_term_discount_percent')
    .single()
  if (error) throw error
  return { ...data, full_term_discount_percent: Number(data.full_term_discount_percent) }
}
