import { supabase } from '@/lib/supabaseClient'

export interface VenuePaymentSettings {
  venue_id: string
  bank_name: string | null
  bank_code: string | null
  bank_account: string | null
  line_pay_instructions: string | null
  is_active: boolean
}

export async function fetchVenuePaymentSettings(
  venueId: string,
): Promise<VenuePaymentSettings | null> {
  const { data, error } = await supabase
    .from('venue_payment_settings')
    .select('venue_id,bank_name,bank_code,bank_account,line_pay_instructions,is_active')
    .eq('venue_id', venueId)
    .maybeSingle()

  if (error) throw new Error(error.message)

  return data as VenuePaymentSettings | null
}
