/**
 * 手寫的資料庫型別（Registration MVP 範圍）。
 *
 * 正式的 `supabase gen types typescript` 需要連上真正的 Supabase 專案才能
 * 產生（Phase 2 完成報告「Not Implemented」第 6 項已記錄此限制），這個雲端
 * 沙盒環境同樣沒有真正的專案連線可用。這裡先手寫最小必要的型別，涵蓋
 * Registration MVP 用到的欄位；等你在本機執行 `supabase gen types
 * typescript --local` 後，可以直接用產生的型別取代或補充這個檔案。
 */

export type UserRoleName = 'student' | 'admin'

export interface Profile {
  id: string
  phone: string | null
  name: string | null
  line_id: string | null
  remit_last5: string | null
  created_at: string
  updated_at: string
}

export interface UserRole {
  id: string
  user_id: string
  role: UserRoleName
  created_at: string
}

export interface Venue {
  id: string
  name: string
  address: string | null
  business_mode: 'self_operated' | 'external_center'
  is_active: boolean
  is_public: boolean
  created_at: string
}

export interface Term {
  id: string
  venue_id: string
  name: string
  start_date: string
  end_date: string
  is_active: boolean
}

export interface DanceClass {
  id: string
  venue_id: string
  term_id: string
  name: string
  weekdays: number[]
  start_time: string
  end_time: string
  capacity: number
  business_mode: 'self_operated' | 'external_center'
  full_term_price: number
  single_session_price: number | null
  default_base_makeup_capacity: number
  is_open_for_registration: boolean
  is_active: boolean
}

/** 公開瀏覽頁使用：class + 場地/期別名稱 + 即時剩餘名額（來自 fn_class_remaining_seats）。 */
export interface ClassWithAvailability extends DanceClass {
  venue_name: string
  term_name: string
  remaining_seats: number | null
}

export interface Order {
  id: string
  student_id: string
  venue_id: string
  status: 'confirmed' | 'cancelled'
  subtotal_amount: number
  total_amount: number
  created_at: string
}

export type RegistrationType = 'full_term' | 'single_session'
export type RegistrationStatus = 'active' | 'cancelled'

export interface Registration {
  id: string
  student_id: string
  class_id: string
  term_id: string
  order_id: string
  class_session_id: string | null
  registration_type: RegistrationType
  status: RegistrationStatus
  created_at: string
  cancelled_at: string | null
  cancelled_reason: string | null
}

/** 「我的報名」/ Admin 報名清單頁用：registration + class/venue 名稱。 */
export interface RegistrationWithClass extends Registration {
  class_name: string
  venue_id: string
  venue_name: string
  term_name: string
  total_amount: number
  payment_status: 'pending' | 'paid'
  payment_method: 'bank_transfer' | 'line_pay' | null
  payment_reference: string | null
  paid_at: string | null
}

export type RegistrationFailureReason = 'not_found' | 'not_open' | 'already_registered' | 'full'

export interface RegistrationFailure {
  class_id: string
  class_name?: string
  reason: RegistrationFailureReason
}

/** rpc_submit_full_term_registrations() 的回傳結構。 */
export interface SubmitRegistrationsResult {
  success: boolean
  failures: RegistrationFailure[]
  order_ids: string[]
  registration_ids: string[]
  classes?: Array<{ class_id: string; class_name: string; registration_id: string }>
}


