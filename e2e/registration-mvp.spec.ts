import { test, expect } from '@playwright/test'

/**
 * Registration MVP（P0）核心路徑 e2e：
 *   管理員核准並建立邀請 → 學生註冊 → 安全登入 → 瀏覽期課 → 多選報名。
 *
 * 執行前置條件（本機執行，見 REGISTRATION_MVP_P0_COMPLETION_REPORT.md）：
 *   1. `npx supabase start`（本機 Supabase Local 已啟動且已套用最新 migration）
 *   2. 執行過 `supabase/seed/registration_mvp_seed.sql`，且班級名稱維持腳本
 *      內建的預設值（爵士舞初階／KPOP 舞蹈／女子舞蹈），或依實際班級名稱
 *      調整下方 CLASS_A / CLASS_B 常數。
 *   3. `.env.e2e` 指向本機 Supabase（VITE_SUPABASE_URL=http://127.0.0.1:18081
 *      等），Playwright 會透過 Vite 的 e2e mode 自動載入此設定。
 *
 * 完整流程只允許指向隔離本機 Supabase，並需要 E2E_ADMIN_EMAIL / PASSWORD。
 * 每次執行都用亂數手機號碼，由管理員先建立與該手機綁定的單次邀請碼。
 */

const CLASS_A = '爵士舞初階'
const CLASS_B = 'KPOP 舞蹈'

function randomTaiwanPhone(): string {
  const suffix = Math.floor(10000000 + Math.random() * 89999999)
  return `09${suffix}`.slice(0, 10)
}

test('student can register, browse, multi-select, and submit a full-term registration', async ({
  page,
}) => {
  const adminEmail = process.env.E2E_ADMIN_EMAIL
  const adminPassword = process.env.E2E_ADMIN_PASSWORD
  expect(adminEmail, 'E2E_ADMIN_EMAIL must be set for the isolated LOCAL admin').toBeTruthy()
  expect(adminPassword, 'E2E_ADMIN_PASSWORD must be set for the isolated LOCAL admin').toBeTruthy()
  const phone = randomTaiwanPhone()
  const pin = '284915' // 6 位數，非全同/非連續，通過前端弱 PIN 檢查

  await page.goto('/admin/login')
  await page.getByLabel('Email').fill(adminEmail!)
  await page.getByLabel('密碼').fill(adminPassword!)
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page).toHaveURL(/\/admin\/registrations$/)
  await page.goto('/admin/students')
  page.once('dialog', (dialog) => dialog.accept())
  await page.getByLabel('學生手機號碼').first().fill(phone)
  await page.getByLabel('核對方式／備註（選填）').fill('Playwright isolated local E2E')
  await page.getByRole('button', { name: '建立邀請碼' }).click()
  const invitationCode = (await page.locator('[role="status"] .font-mono').first().textContent())?.trim()
  expect(invitationCode).toMatch(/^[A-Z2-9]{12}$/)
  await page.getByRole('button', { name: '登出' }).click()

  await page.goto('/register')
  await page.getByLabel('手機號碼').fill(phone)
  await page.getByLabel('安全邀請碼').fill(invitationCode!)
  await page.getByLabel('設定 6 位數 PIN').fill(pin)
  await page.getByLabel('再次輸入 PIN').fill(pin)
  await page.getByRole('button', { name: '註冊' }).click()

  await expect(page).toHaveURL(/\/courses$/)
  await page.getByRole('button', { name: '登出' }).click()
  await page.goto('/login')
  await page.getByLabel('手機號碼').fill(phone)
  await page.getByLabel('PIN').fill(pin)
  await page.getByRole('button', { name: '登入' }).click()
  await expect(page).toHaveURL(/\/courses$/)

  const classARow = page.locator('li').filter({ hasText: CLASS_A })
  const classBRow = page.locator('li').filter({ hasText: CLASS_B })
  await expect(classARow).toBeVisible()
  await expect(classBRow).toBeVisible()

  await classARow.getByRole('checkbox').check()
  await classBRow.getByRole('checkbox').check()

  await page.getByRole('button', { name: /送出報名/ }).click()

  await expect(page.getByText('報名已送出，名額已為你保留！')).toBeVisible()
  await expect(page.locator('li').filter({ hasText: CLASS_A }).last()).toBeVisible()
  await expect(page.locator('li').filter({ hasText: CLASS_B }).last()).toBeVisible()

  await page.getByRole('link', { name: '前往付款' }).click()
  await expect(page).toHaveURL(/\/my-registrations$/)
  await expect(page.getByText(CLASS_A)).toBeVisible()
  await expect(page.getByText(CLASS_B)).toBeVisible()
})

test('public account creation cannot claim a phone without an admin invitation', async ({ page }) => {
  await page.goto('/register')
  await page.getByLabel('手機號碼').fill(randomTaiwanPhone())
  await page.getByLabel('安全邀請碼').fill('ABCD2345EFGH')
  await page.getByLabel('設定 6 位數 PIN').fill('284915')
  await page.getByLabel('再次輸入 PIN').fill('284915')
  await page.getByRole('button', { name: '註冊' }).click()
  await expect(page).toHaveURL(/\/register$/)
  await expect(page.getByText('邀請碼無效或已失效，請聯絡老師')).toBeVisible()
})
