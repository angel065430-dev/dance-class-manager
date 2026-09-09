import { describe, expect, it } from 'vitest'
import { functionErrorMessage } from '@/utils/functionErrors'

describe('Edge Function public error handling', () => {
  it('shows an explicitly approved backend message', async () => {
    const error = {
      context: new Response(JSON.stringify({ error: '邀請碼無效或已失效，請聯絡老師' }), {
        status: 403,
        headers: { 'content-type': 'application/json' },
      }),
    }
    await expect(functionErrorMessage(error, 'fallback')).resolves.toBe(
      '邀請碼無效或已失效，請聯絡老師',
    )
  })

  it.each([
    { error: 'relation secret_table does not exist' },
    { error: 'service_role token leaked', stack: 'private stack' },
    { message: 'internal error' },
  ])('does not expose an unapproved backend payload', async (body) => {
    const error = { context: new Response(JSON.stringify(body), { status: 500 }) }
    await expect(functionErrorMessage(error, '安全的一般錯誤')).resolves.toBe('安全的一般錯誤')
  })

  it('falls back for non-JSON routing errors', async () => {
    const error = { context: new Response('Function not found', { status: 404 }) }
    await expect(functionErrorMessage(error, '邀請建立失敗')).resolves.toBe('邀請建立失敗')
  })
})
