const publicFunctionMessages = new Set([
  '請輸入正確的台灣手機號碼',
  'PIN 必須為 6 位數字，且不可全部相同或連號',
  '邀請碼無效或已失效，請聯絡老師',
  '帳號安全檢查暫時無法完成，請稍後再試',
  '建立帳號次數過多，請稍後再試或聯絡老師',
  '此號碼無法建立或已經有帳號，請嘗試登入或聯絡老師',
  '帳號建立失敗',
  '帳號資料建立失敗，請稍後再試',
  '帳號安全確認失敗，請聯絡老師',
  '手機號碼或 PIN 錯誤',
  '嘗試次數過多，請 15 分鐘後再試或聯絡老師',
  '登入安全檢查暫時無法完成，請稍後再試',
  '登入安全確認失敗，請稍後再試',
  '此手機已有帳號，請使用 PIN 重設流程',
  '帳號檢查失敗',
  '邀請建立失敗，未產生可用邀請碼',
  '帳號查詢失敗',
  '找不到此學生帳號',
  '請填寫 PIN 重設原因',
  '稽核紀錄失敗，PIN 未重設',
  'PIN 重設失敗',
  'PIN 重設與失敗稽核皆未完成，請聯絡系統管理員',
  'PIN 已變更但完成稽核失敗；請立即再次重設，不要將本次 PIN 提供給學生',
])

function publicMessage(value: unknown): string | null {
  if (!value || typeof value !== 'object') return null
  const message = (value as { error?: unknown }).error
  return typeof message === 'string' && publicFunctionMessages.has(message) ? message : null
}

/** Read an Edge Function error body, but expose only explicitly approved messages. */
export async function functionErrorMessage(error: unknown, fallback: string): Promise<string> {
  if (!error || typeof error !== 'object') return fallback
  const context = (error as { context?: unknown }).context
  if (!(context instanceof Response)) return fallback

  // Safe operational signal: never log the response body or request headers,
  // since either may contain internal details or credentials.
  console.warn(
    `[Edge Function request failed] status=${context.status} content-type=${context.headers.get('content-type') ?? '(missing)'}`,
  )

  try {
    return publicMessage(await context.clone().json()) ?? fallback
  } catch {
    return fallback
  }
}
