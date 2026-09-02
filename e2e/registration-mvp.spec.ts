import { test, expect } from '@playwright/test'

/**
 * Registration MVP（P0）核心路徑 e2e：
 *   學生註冊 → 瀏覽期課 → 一次選擇多堂 → 送出報名 → 看到成功確認。
 *
 * 執行前置條件（本機執行，見 REGISTRATION_MVP_P0_COMPLETION_REPORT.md）：
 *   1. `npx supabase start`（本機 Supabase Local 已啟動且已套用最新 migration）
 *   2. 執行過 `supabase/seed/registration_mvp_seed.sql`，且班級名稱維持腳本
 *      內建的預設值（爵士舞初階／KPOP 舞蹈／女子舞蹈），或依實際班級名稱
 *      調整下方 CLASS_A / CLASS_B 常數。
 *   3. `.env.local` 指向本機 Supabase（VITE_SUPABASE_URL=http://127.0.0.1:54321
 *      等），`npm run dev` 或 `npm run preview` 正在執行。
 *
 * 每次執行都用亂數手機號碼註冊全新學生帳號，避免重複執行時撞到
 * 「已報名過」或手機號碼重複註冊的錯誤。
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
  const phone = randomTaiwanPhone()
  const pin = '284915' // 6 位數，非全同/非連續，通過前端弱 PIN 檢查

  await page.goto('/register')
  await page.getByLabel('手機號碼').fill(phone)
  await page.getByLabel('設定 6 位數 PIN').fill(pin)
  await page.getByLabel('再次輸入 PIN').fill(pin)
  await page.getByRole('button', { name: '註冊' }).click()

  await expect(page).toHaveURL(/\/courses$/)

  const classARow = page.locator('li').filter({ hasText: CLASS_A })
  const classBRow = page.locator('li').filter({ hasText: CLASS_B })
  await expect(classARow).toBeVisible()
  await expect(classBRow).toBeVisible()

  await classARow.getByRole('checkbox').check()
  await classBRow.getByRole('checkbox').check()

  await page.getByRole('button', { name: /送出報名/ }).click()

  await expect(page.getByText('報名成功！')).toBeVisible()
  await expect(page.getByText(CLASS_A)).toBeVisible()
  await expect(page.getByText(CLASS_B)).toBeVisible()

  await page.getByRole('link', { name: '查看我的報名' }).click()
  await expect(page).toHaveURL(/\/my-registrations$/)
  await expect(page.getByText(CLASS_A)).toBeVisible()
  await expect(page.getByText(CLASS_B)).toBeVisible()
})
