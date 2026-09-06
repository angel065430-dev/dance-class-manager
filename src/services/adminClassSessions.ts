import { supabase } from '@/lib/supabaseClient'

export type ClassSessionStatus = 'scheduled' | 'cancelled'

export interface AdminClassSession {
  id: string
  class_id: string
  session_date: string
  start_at: string
  end_at: string
  status: ClassSessionStatus
  base_makeup_capacity: number
  notes: string | null
  created_at: string
  updated_at: string
}

export async function fetchAdminClassSessions(
  classId: string,
): Promise<AdminClassSession[]> {
  const { data, error } = await supabase
    .from('class_sessions')
    .select(
      'id,class_id,session_date,start_at,end_at,status,base_makeup_capacity,notes,created_at,updated_at',
    )
    .eq('class_id', classId)
    .order('session_date', { ascending: true })

  if (error) {
    throw new Error(error.message)
  }

  return (data ?? []) as AdminClassSession[]
}

export async function generateAdminClassSessions(
  classId: string,
): Promise<number> {
  const { data, error } = await supabase.rpc('rpc_generate_class_sessions', {
    p_class_id: classId,
  })

  if (error) {
    throw new Error(error.message)
  }

  return Number(data ?? 0)
}

export async function updateAdminClassSessionStatus(
  sessionId: string,
  status: ClassSessionStatus,
): Promise<AdminClassSession> {
  const { data, error } = await supabase
    .from('class_sessions')
    .update({ status })
    .eq('id', sessionId)
    .select(
      'id,class_id,session_date,start_at,end_at,status,base_makeup_capacity,notes,created_at,updated_at',
    )
    .single()

  if (error) {
    throw new Error(error.message)
  }

  return data as AdminClassSession
}
