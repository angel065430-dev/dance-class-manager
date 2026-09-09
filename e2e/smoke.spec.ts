import { test, expect } from '@playwright/test'

/**
 * Phase 1 e2e smoke test — 只驗證頁面能正常啟動並渲染首頁文字。
 * 第一批真正的業務流程 e2e（搶名額、優惠碼併發等，見
 * PHASE_0_AUDIT_REPORT.md 第 8.3 節）將於對應功能完成的 Phase 補上。
 */
test('homepage renders the app title', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Angel Zumba 課程' })).toBeVisible()
})
