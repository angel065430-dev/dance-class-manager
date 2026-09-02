import { defineConfig, devices } from '@playwright/test'

/**
 * Playwright 基礎設定（Phase 1）。
 * 此階段僅提供一個對首頁的 smoke test，不含任何業務流程測試。
 * 業務流程 e2e（報名搶位、優惠碼併發等，見 PHASE_0_AUDIT_REPORT.md 第 8.3 節）
 * 將於對應 Phase 完成後逐步補上。
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'npm run preview',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI,
  },
})
