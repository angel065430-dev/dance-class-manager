import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '@/pages/HomeView.vue'
import { useAuth } from '@/composables/useAuth'

/**
 * Router — Registration MVP（P0）路由表。
 *
 * 提醒：以下路由守衛只是 UX 層級的便利（避免使用者點進一個顯然用不到的頁面），
 * 不是安全邊界，真正的存取控制一律由 Supabase RLS + Role 在後端強制執行
 * （AI_INSTRUCTIONS.md 第 10-11 節）。即使守衛邏輯有漏洞，後端也不會因此
 * 洩漏或允許修改不該存取的資料。
 */
const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView,
    },
    {
      path: '/login',
      name: 'student-login',
      component: () => import('@/pages/student/LoginView.vue'),
    },
    {
      path: '/register',
      name: 'student-register',
      component: () => import('@/pages/student/RegisterView.vue'),
    },
    {
      path: '/courses',
      name: 'courses',
      component: () => import('@/pages/student/CoursesView.vue'),
    },
    {
      path: '/my-registrations',
      name: 'my-registrations',
      component: () => import('@/pages/student/MyRegistrationsView.vue'),
      meta: { requiresStudent: true },
    },
    {
      path: '/admin/login',
      name: 'admin-login',
      component: () => import('@/pages/admin/AdminLoginView.vue'),
    },
    {
      path: '/admin/registrations',
      name: 'admin-registrations',
      component: () => import('@/pages/admin/AdminRegistrationsView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/classes',
      name: 'admin-classes',
      component: () => import('@/pages/admin/AdminClassesView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/venues',
      name: 'admin-venues',
      component: () => import('@/pages/admin/AdminVenuesView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/admin/terms',
      name: 'admin-terms',
      component: () => import('@/pages/admin/AdminTermsView.vue'),
      meta: { requiresAdmin: true },
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('@/pages/NotFoundView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresStudent && !to.meta.requiresAdmin) {
    return true
  }

  const { init, isLoggedIn, isAdmin } = useAuth()
  await init()

  if (to.meta.requiresAdmin) {
    if (!isLoggedIn.value || !isAdmin.value) {
      return { name: 'admin-login' }
    }
  } else if (to.meta.requiresStudent) {
    if (!isLoggedIn.value) {
      return { name: 'student-login' }
    }
  }

  return true
})

export default router
