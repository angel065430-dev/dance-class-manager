import { readFileSync } from 'node:fs'
import { expect, test, type APIResponse } from '@playwright/test'

function e2eSetting(name: string): string {
  const line = readFileSync('.env.e2e', 'utf8')
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .find((entry) => entry.startsWith(`${name}=`))
  return line?.slice(name.length + 1).trim() ?? ''
}

const supabaseUrl = e2eSetting('VITE_SUPABASE_URL')
const anonKey = e2eSetting('VITE_SUPABASE_ANON_KEY')

function authEndpoint(path: string): string {
  expect(supabaseUrl, 'VITE_SUPABASE_URL must be set in .env.e2e').toBeTruthy()
  expect(anonKey, 'VITE_SUPABASE_ANON_KEY must be set in .env.e2e').toBeTruthy()
  return new URL(path, `${supabaseUrl.replace(/\/$/, '')}/`).toString()
}

function safeText(raw: string): string {
  return raw
    .slice(0, 500)
    .replace(/("(?:access_token|refresh_token|token|password|apikey)"\s*:\s*")[^"]*(")/gi, '$1[REDACTED]$2')
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[REDACTED_JWT]')
}

async function readJson(response: APIResponse, operation: string): Promise<Record<string, unknown>> {
  const contentType = response.headers()['content-type'] ?? '(missing)'
  const raw = await response.text()
  const diagnostic = `${operation}: HTTP ${response.status()}, content-type=${contentType}, text=${JSON.stringify(safeText(raw))}`

  expect(contentType.toLowerCase(), diagnostic).toContain('application/json')
  try {
    return JSON.parse(raw) as Record<string, unknown>
  } catch {
    throw new Error(`${diagnostic}; response body is not valid JSON`)
  }
}

test.describe('LOCAL Auth configuration', () => {
  test('an existing admin can sign in with email and password', async ({ request }) => {
    const email = process.env.E2E_ADMIN_EMAIL
    const password = process.env.E2E_ADMIN_PASSWORD
    expect(email, 'E2E_ADMIN_EMAIL must identify an existing LOCAL admin').toBeTruthy()
    expect(password, 'E2E_ADMIN_PASSWORD must be set for that LOCAL admin').toBeTruthy()

    const response = await request.post(authEndpoint('/auth/v1/token?grant_type=password'), {
      headers: { apikey: anonKey, 'Content-Type': 'application/json' },
      data: { email, password },
    })

    const body = await readJson(response, 'admin password grant')
    expect(response.status(), `admin password grant: HTTP ${response.status()}`).toBe(200)
    expect(body.access_token).toBeTruthy()
    expect((body.user as { email?: unknown } | undefined)?.email).toBe(email)
  })

  test('the backend rejects public email signup', async ({ request }) => {
    const response = await request.post(authEndpoint('/auth/v1/signup'), {
      headers: { apikey: anonKey, 'Content-Type': 'application/json' },
      data: {
        email: `uninvited-${crypto.randomUUID()}@example.invalid`,
        password: `Blocked-${crypto.randomUUID()}-9a!`,
      },
    })

    expect(response.ok(), 'Public signup unexpectedly created an account').toBe(false)
    const body = await readJson(response, 'public email signup')
    expect(body.access_token).toBeFalsy()
    expect(body.user).toBeFalsy()
    expect(JSON.stringify(body).toLowerCase()).toContain('signup')
  })
})
