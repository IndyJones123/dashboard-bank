<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { currentUser, isLoggedIn, logout } from './stores/auth'
import { enterPresent, exitPresent, isPresent } from './stores/present'

const router = useRouter()
const route = useRoute()

/* Konteks kanan navbar: tanggal untuk tamu, sapaan + nama untuk user login */
const topContext = computed(() => {
  if (isLoggedIn.value && currentUser.value) {
    const h = new Date().getHours()
    const sapa = h < 11 ? 'Selamat pagi' : h < 15 ? 'Selamat siang' : h < 18 ? 'Selamat sore' : 'Selamat malam'
    return `${sapa}, ${currentUser.value.full_name || currentUser.value.username}`
  }
  return new Date().toLocaleDateString('id-ID', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
})

/* ---- Drawer sidebar (mobile) ----
   Tampil di layar ≤860px: hamburger di topbar membuka sidebar sebagai drawer
   off-canvas. Tutup otomatis saat pindah halaman, klik backdrop, atau Esc. */
const sideOpen = ref(false)
watch(() => route.path, () => {
  sideOpen.value = false
})
function onKeydown(e: KeyboardEvent) {
  if (e.key !== 'Escape') return
  // Esc: tutup drawer (mobile) DAN/KALAU sedang present -> keluar present mode.
  // (Saat fullscreen aktif, browser juga memicu fullscreenchange -> exitPresent
  // berjalan dua kali dengan aman, isPresent sudah false di panggilan kedua.)
  if (sideOpen.value) sideOpen.value = false
  if (isPresent.value) void exitPresent()
}
onMounted(() => document.addEventListener('keydown', onKeydown))
onUnmounted(() => document.removeEventListener('keydown', onKeydown))

/* ---- Present Mode ----
   Pindah ke /reports dulu (guard auth boleh redirect ke login), baru masuk
   fullscreen, present tidak pernah aktif di halaman lain. */
function onPresent() {
  const go = route.path === '/reports' ? Promise.resolve() : router.push('/reports')
  void go.then(() => {
    if (route.path === '/reports') void enterPresent()
  })
}

function onLogout() {
  logout()
  router.push('/login')
}
</script>

<template>
  <div class="app">
    <!-- Navbar putih full-width (ref: clip_20261015_094010_3) -->
    <header class="topbar">
      <div class="top-left">
        <!-- Hamburger: hanya tampil di layar ≤860px -->
        <button
          type="button"
          class="side-toggle"
          :aria-expanded="sideOpen"
          aria-label="Buka menu navigasi"
          @click="sideOpen = !sideOpen"
        >
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        </button>

        <RouterLink to="/" class="brand">
          <span class="brand-mark">
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true" style="width: 20px; height: 20px">
              <path d="M4 10h16M5 10v9M19 10v9M9 10v9M15 10v9M3 21h18M12 3l8 5H4l8-5z" />
            </svg>
          </span>
          <span class="brand-name">
            BankDash
            <em>Treasury Command</em>
          </span>
        </RouterLink>
      </div>

      <div class="top-actions">
        <span class="top-context">{{ topContext }}</span>
        <!-- Present Mode: klik -> pindah ke /reports + mode fullscreen slideshow -->
        <button type="button" class="btn-navy" aria-label="Present Mode" @click="onPresent">
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3 4h18v12H3zM8 20h8M12 16v4" />
          </svg>
          <span class="btn-label">Present Mode</span>
        </button>
        <RouterLink v-if="!isLoggedIn" to="/login" class="btn-ghost" aria-label="Login">
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4M10 8l-4 4 4 4M6 12h11" />
          </svg>
          <span class="btn-label">Login</span>
        </RouterLink>
        <button v-else type="button" class="btn-ghost" aria-label="Keluar" @click="onLogout">
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M9 4H5a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h4M14 8l4 4-4 4M18 12H8" />
          </svg>
          <span class="btn-label">Keluar</span>
        </button>
      </div>
    </header>

    <!-- Backdrop drawer mobile (klik untuk menutup) -->
    <div v-if="sideOpen" class="side-backdrop" @click="sideOpen = false" />

    <div class="shell">
      <!-- Sidebar: 4 menu (ref: clip_20261015_094010_3) -->
      <aside :class="['sidebar', { open: sideOpen }]">
        <div class="side-user">
          <span :class="['avatar', { guest: !isLoggedIn }]">
            {{ (currentUser?.full_name || currentUser?.username || '?').slice(0, 2).toUpperCase() }}
          </span>
          <span class="side-user-info">
            <strong>{{ currentUser?.full_name || currentUser?.username || 'Tamu' }}</strong>
            <small>{{ isLoggedIn ? currentUser?.role : 'Belum login' }}</small>
          </span>
        </div>

        <p class="side-label">Menu Utama</p>
        <nav class="side-nav" aria-label="Navigasi utama">
          <!-- 1. Dashboard -->
          <RouterLink to="/" class="side-link" exact-active-class="active">
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
              <rect x="3.5" y="3.5" width="7" height="7" rx="1.5" />
              <rect x="13.5" y="3.5" width="7" height="7" rx="1.5" />
              <rect x="3.5" y="13.5" width="7" height="7" rx="1.5" />
              <rect x="13.5" y="13.5" width="7" height="7" rx="1.5" />
            </svg>
            Dashboard
          </RouterLink>

          <!-- 2. Laporan Keuangan (dikerjakan sekarang) -->
          <RouterLink to="/reports" class="side-link" active-class="active">
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 3.5h8l4 4v13H6zM14 3.5v4h4M9.5 13h5M9.5 16.5h5" />
            </svg>
            Laporan Keuangan
          </RouterLink>

          <!-- 3. Likuiditas (menyusul) -->
          <span class="side-link is-disabled" aria-disabled="true" title="Halaman segera hadir">
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M12 3.5s5.5 6.1 5.5 9.5a5.5 5.5 0 0 1-11 0c0-3.4 5.5-9.5 5.5-9.5z" />
            </svg>
            Likuiditas
            <span class="side-soon">Segera</span>
          </span>

          <!-- 4. Pembiayaan (menyusul) -->
          <span class="side-link is-disabled" aria-disabled="true" title="Halaman segera hadir">
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M3.5 7.5A2 2 0 0 1 5.5 5.5h11a2 2 0 0 1 2 2v1a2 2 0 0 0 0 4v1a2 2 0 0 1-2 2h-11a2 2 0 0 1-2-2zM16.5 11.5h2.5" />
            </svg>
            Pembiayaan
            <span class="side-soon">Segera</span>
          </span>
        </nav>

        <a class="stage-broadcast" href="#" @click.prevent="router.push('/')">
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4 11v2a1 1 0 0 0 1 1h2l4 4V6L7 10H5a1 1 0 0 0-1 1zM16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11" />
          </svg>
          Stage Broadcast
        </a>
      </aside>

      <div class="content">
        <main class="main">
          <RouterView />
        </main>
      </div>
    </div>

    <!-- Tombol keluar Present Mode (topbar tersembunyi selama present) -->
    <button
      v-if="isPresent"
      type="button"
      class="present-exit"
      aria-label="Keluar Present Mode"
      @click="exitPresent"
    >
      <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M6 6l12 12M18 6L6 18" />
      </svg>
      <span class="btn-label">Keluar Present</span>
    </button>
  </div>
</template>
