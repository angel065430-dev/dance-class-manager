import { defineConfig, devices } from '@playwright/test'

/**
 * Playwright 基礎設定。
 *
 * E2E 測試使用 Vite 的 e2e mode，因此會載入：
 *
 *   .env.e2e
 *
 * 讓測試連線到本機 Supabase，而平常開發使用 .env.local
 * 連線到雲端 Supabase。
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'npm run dev -- --mode e2e --host 127.0.0.1 --port 4173 --strictPort',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: false,
  },
})
