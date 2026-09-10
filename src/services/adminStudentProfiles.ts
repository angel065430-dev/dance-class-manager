import { supabase } from '@/lib/supabaseClient'

export interface AdminStudentProfile {
  id: string
  name: string | null
  line_display_name: string | null
  phone: string | null
  created_at: string
}

export async function fetchAdminStudentProfiles(): Promise<AdminStudentProfile[]> {
  const { data, error } = await supabase.from('profiles')
    .select('id, name, line_display_name, phone, created_at, user_roles!inner(role)')
    .eq('user_roles.role', 'student')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data ?? []
}
