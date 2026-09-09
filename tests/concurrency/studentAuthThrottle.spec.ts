import { createHash, randomUUID } from 'node:crypto'
import { describe, expect, it } from 'vitest'

const url = process.env.LOCAL_SUPABASE_URL
const serviceKey = process.env.LOCAL_SUPABASE_SERVICE_ROLE_KEY
const enabled = Boolean(url && serviceKey)

async function rpc<T>(name: string, body: object): Promise<T> {
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { apikey: serviceKey!, Authorization: `Bearer ${serviceKey!}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!response.ok) throw new Error(`${name} failed with ${response.status}`)
  return response.json() as Promise<T>
}

describe.skipIf(!enabled)('atomic student auth throttles (isolated local Supabase)', () => {
  it('allows exactly ten out of twenty concurrent signup attempts', async () => {
    const hash = createHash('sha256').update(randomUUID()).digest('hex')
    const results = await Promise.all(Array.from({ length: 20 }, () =>
      rpc<Array<{ allowed: boolean }>>('consume_student_signup_attempt', {
        p_client_hash: hash, p_limit: 10, p_window: '01:00:00',
      }),
    ))
    expect(results.flat().filter((result) => result.allowed)).toHaveLength(10)
  })

  it('serializes concurrent login reservations and locks after five', async () => {
    const hash = createHash('sha256').update(randomUUID()).digest('hex')
    const results = await Promise.all(Array.from({ length: 12 }, () =>
      rpc<Array<{ allowed: boolean }>>('reserve_student_login_attempt', {
        p_phone_hash: hash, p_limit: 5, p_lock_duration: '00:15:00',
      }),
    ))
    expect(results.flat().filter((result) => result.allowed)).toHaveLength(5)
  })
})
