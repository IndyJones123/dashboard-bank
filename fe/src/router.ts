import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { isAdmin, isLoggedIn } from './stores/auth'
import { pageGuestOK } from './stores/widgets'
import { REPORT_KINDS } from './report-helpers'
import AccountsView from './views/Accounts.vue'
import CmsView from './views/Cms.vue'
import DashboardView from './views/Dashboard.vue'
import LoginView from './views/Login.vue'
import PembiayaanView from './views/Pembiayaan.vue'
import LikuiditasView from './views/Likuiditas.vue'
import ReportsView from './views/Reports.vue'

const routes: RouteRecordRaw[] = [
  { path: '/', name: 'dashboard', component: DashboardView },
  { path: '/login', name: 'login', component: LoginView },
  // Halaman khusus login, tidak bisa diakses user biasa (guest)
  { path: '/accounts', name: 'accounts', component: AccountsView, meta: { requiresAuth: true } },
  // CMS (admin only): editor tema global palet fitlink
  { path: '/cms', name: 'cms', component: CmsView, meta: { requiresAuth: true, requiresAdmin: true } },
  // Halaman ber-widget: tamu boleh masuk bila admin mengizinkan minimal 1
  // widget utk tamu (CMS > Widget Setting); selain itu diarahkan ke /login
  { path: '/reports', name: 'reports', component: ReportsView, meta: { widgetPage: 'reports' } },
  // Menu sidebar "menyusul" -> sudah ada halaman (placeholder jujur, tanpa angka)
  { path: '/likuiditas', name: 'likuiditas', component: LikuiditasView, meta: { widgetPage: 'likuiditas' } },
  { path: '/pembiayaan', name: 'pembiayaan', component: PembiayaanView, meta: { widgetPage: 'pembiayaan' } },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  // Navigasi baru -> mulai dari atas (WAJIB utk Live Mode carousel: tiap
  // slide harus dibuka dari posisi scroll 0). Back/forward browser memakai
  // posisi tersimpan (savedPosition) agar perilaku native tidak berubah.
  scrollBehavior(_to, _from, savedPosition) {
    return savedPosition ?? { top: 0 }
  },
})

// HAMBATAN AKSES: guest yang buka halaman login-only dilempar ke /login;
// halaman admin (meta requiresAdmin) utk non-admin dilempar ke beranda.
router.beforeEach((to) => {
  if (to.meta.requiresAuth && !isLoggedIn.value) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
  if (to.meta.requiresAdmin && !isAdmin.value) {
    return { name: 'dashboard' }
  }
  const wp = to.meta.widgetPage as string | undefined
  if (wp && !isLoggedIn.value) {
    const toLogin = { name: 'login', query: { redirect: to.fullPath } }
    if (wp !== 'reports') return pageGuestOK(wp) ? true : toLogin
    // Laporan: jenis yg diminta tertutup utk tamu -> jenis pertama yg terbuka
    const asked = typeof to.query.jenis === 'string' ? to.query.jenis : 'aset'
    if (pageGuestOK(`reports-${asked}`)) return true
    const alt = REPORT_KINDS.find((k) => pageGuestOK(`reports-${k}`))
    return alt ? { path: '/reports', query: { ...to.query, jenis: alt } } : toLogin
  }
  return true
})

export default router
