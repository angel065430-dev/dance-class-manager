import 'vue-router'

/**
 * Registration MVP（P0）路由守衛用的 meta 欄位（見 src/router/index.ts）。
 * 這些只是 UX 層級的路由導引旗標，不是安全邊界，真正的存取控制一律由
 * Supabase RLS + Role 在後端強制執行（AI_INSTRUCTIONS.md 第 10-11 節）。
 */
declare module 'vue-router' {
  interface RouteMeta {
    requiresStudent?: boolean
    requiresAdmin?: boolean
  }
}
