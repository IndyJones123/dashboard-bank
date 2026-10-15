import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { isLoggedIn } from './stores/auth'
import AccountsView from './views/Accounts.vue'
import DashboardView from './views/Dashboard.vue'
import LoginView from './views/Login.vue'
import ReportsView from './views/Reports.vue'

const routes: RouteRecordRaw[] = [
  { path: '/', name: 'dashboard', component: DashboardView },
  { path: '/login', name: 'login', component: LoginView },
  // Halaman khusus login — tidak bisa diakses user biasa (guest)
  { path: '/accounts', name: 'accounts', component: AccountsView, meta: { requiresAuth: true } },
  { path: '/reports', name: 'reports', component: ReportsView, meta: { requiresAuth: true } },
]

const router = createRouter({ history: createWebHistory(), routes })

// HAMBATAN AKSES: guest yang buka halaman login-only dilempar ke /login
router.beforeEach((to) => {
  if (to.meta.requiresAuth && !isLoggedIn.value) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
