import { supabase } from '@/lib/supabaseClient'

export type PublicClassSessionStatus = 'scheduled' | 'cancelled'

export interface PublicClassSession {
  id: string
  class_id: string
  session_date: string
  start_at: string
  end_at: string
  status: PublicClassSessionStatus
}

export async function fetchPublicClassSessions(
  classIds: string[],
): Promise<PublicClassSession[]> {
  if (classIds.length === 0) {
    return []
  }

  const { data, error } = await supabase
    .from('class_sessions')
    .select('id,class_id,session_date,start_at,end_at,status')
    .in('class_id', classIds)
    .order('session_date', { ascending: true })

  if (error) {
    throw new Error(error.message)
  }

  return (data ?? []) as PublicClassSession[]
}
