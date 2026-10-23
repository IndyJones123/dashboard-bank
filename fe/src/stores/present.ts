import { computed, ref } from 'vue'
import router from '../router'
import { REPORT_KINDS, REPORT_KIND_LABELS } from '../report-helpers'

/* ==========================================================================
   PRESENT MODE: mode fullscreen untuk slideshow presentasi.
   Tombol "Present Mode" di topbar memanggil enterPresent():
     1. Fullscreen API diaktifkan (documentElement) -> layar penuh tanpa chrome
     2. class `present-mode` dipasang di <body> -> topbar/sidebar disembunyikan
        CSS, konten melebar (max-width 1600px), slide jadi bersih.
   Kalau Fullscreen API ditolak/tidak tersedia (mis. iOS/iPadOS Safari),
   class CSS tetap dipasang -> tampilan present tetap rapi walau chrome
   browser masih terlihat (fallback).
   Keluar: tombol mengambang "Keluar Present", Esc (native fullscreen /
   fallback), atau fullscreenchange (user keluar sendiri) -> state disinkronkan.

   DECK SLIDE (lintas menu): urutan slide = menu sidebar x jenis laporan,
   8 slide:
     0 Dashboard | 1-5 Laporan Keuangan (jenis via /reports?jenis=...) |
     6 Likuiditas | 7 Pembiayaan
   Navigasi = router replace (URL selalu mencerminkan slide -> deep-link
   & tombol back/forward browser ikut jalan), transisi ala PowerPoint
   (slide-fwd/slide-back) arah-tergantung di kedua level:
     - level route (App.vue, key = path) utk pindah menu
     - level slide (Reports.vue, key = glKind) utk pindah jenis laporan
   Catatan siklus import: module ini di-import saat router.ts masih dievaluasi
   -> JANGAN menyentuh `router` di top-level; hanya di dalam fungsi/hook yang
   dipanggil sesudah aplikasi siap (afterEach dipasang saat enterPresent).
   ========================================================================== */

export const isPresent = ref(false)

export interface PresentSlide {
  path: string
  /** Jenis laporan (hanya slide /reports); absen = halaman biasa. */
  jenis?: string
  title: string
}

/** Urutan deck Present Mode (lihat comment di atas). */
export const PRESENT_SLIDES: PresentSlide[] = [
  { path: '/', title: 'Dashboard' },
  ...REPORT_KINDS.map((k) => ({ path: '/reports', jenis: k as string, title: REPORT_KIND_LABELS[k] })),
  { path: '/likuiditas', title: 'Likuiditas' },
  { path: '/pembiayaan', title: 'Pembiayaan' },
]

/** Arah transisi slide terakhir ('fwd' = maju -> konten baru masuk dari kanan). */
export const slideDir = ref<'fwd' | 'back'>('fwd')

/* ---- Dropdown pilih modul (Present Mode): grup slide per menu sidebar ---- */
const MODULE_LABELS: Record<string, string> = {
  '/': 'Dashboard',
  '/reports': 'Laporan Keuangan',
  '/likuiditas': 'Likuiditas',
  '/pembiayaan': 'Pembiayaan',
}

export interface PresentModule {
  path: string
  label: string
}

/** 4 modul deck, urut dgn PRESENT_SLIDES (dedupe per path). */
export const PRESENT_MODULES: PresentModule[] = [
  ...new Map(
    PRESENT_SLIDES.map((s) => [s.path, { path: s.path, label: MODULE_LABELS[s.path] ?? s.title }])
  ).values(),
]

/** Path modul slide saat ini (dipakai sbg nilai dropdown). */
export const currentModulePath = computed(() => router.currentRoute.value.path)

/** Index slide dari (path, ?jenis). /reports tanpa ?jenis = slide aset. */
export function slideIndexOf(path: string, jenis: unknown): number {
  const k = typeof jenis === 'string' ? jenis : undefined
  const exact = PRESENT_SLIDES.findIndex((s) => s.path === path && s.jenis === k)
  if (exact >= 0) return exact
  return PRESENT_SLIDES.findIndex((s) => s.path === path) // slide pertama utk path itu
}

/** Index slide route saat ini (reactive: bergantung pada router.currentRoute). */
export const slideIdx = computed(() => {
  const r = router.currentRoute.value
  return slideIndexOf(r.path, r.query.jenis)
})

export const slideTitle = computed(() => PRESENT_SLIDES[slideIdx.value]?.title ?? '')

/** Nama transisi (atau undefined di luar Present Mode) dipakai App.vue & Reports.vue. */
export const slideTransition = computed(() =>
  !isPresent.value ? undefined : slideDir.value === 'fwd' ? 'slide-fwd' : 'slide-back'
)

/** Pindah ke slide i: set arah, lalu replace route/query agar cocok dgn slide. */
export function gotoSlide(i: number): void {
  const ti = Math.min(PRESENT_SLIDES.length - 1, Math.max(0, i))
  const cur = slideIdx.value
  if (ti === cur) return
  if (cur >= 0) slideDir.value = ti > cur ? 'fwd' : 'back'
  const s = PRESENT_SLIDES[ti]
  const query: import('vue-router').LocationQueryRaw = { ...router.currentRoute.value.query }
  if (s.jenis) query.jenis = s.jenis
  else delete query.jenis
  void router.replace({ path: s.path, query })
}

export function prevSlide(): void {
  gotoSlide(slideIdx.value - 1)
}

export function nextSlide(): void {
  gotoSlide(slideIdx.value + 1)
}

/** Pilih modul via dropdown: kalau sudah di modul itu -> biarkan (mis. tetap
    di slide DPK saat pilih "Laporan Keuangan"); selain itu ke slide pertamanya. */
export function gotoModule(path: string): void {
  const cur = slideIdx.value
  if (cur >= 0 && PRESENT_SLIDES[cur]?.path === path) return
  gotoSlide(PRESENT_SLIDES.findIndex((s) => s.path === path))
}

/* ==========================================================================
   LIVE MODE (Present Mode): carousel otomatis slide pertama -> akhir -> loop.
   Per siklus: tunda dulu -> kalau halaman TIDAK muat 1 layar, scroll PELAN
   ke bawah -> tunda lagi -> ganti slide (slide terakhir wrap ke pertama).
   Semua timer/raf lewat liveWakers supaya setLive(false) membatalkan siklus
   berjalan saat itu juga (promise lama di-resolve -> loop lama keluar di
   cek gen/mode).
   ========================================================================== */
export const liveMode = ref(false)

const LIVE_DWELL = 4000       // halaman muat 1 layar: tunda sebelum ganti
const LIVE_TAIL = 3000        // sesudah scroll ke bawah: tunda sebelum ganti
const LIVE_SPEED = 120        // px/detik — kecepatan scroll "pelan"
const LIVE_SCROLL_MAX = 16000 // batas durasi scroll 1 halaman

let liveGen = 0               // penanda generasi loop aktif
let liveWakers: Array<() => void> = [] // resolver sleep/scroll utk cancel
let liveRaf = 0

/** Sleep yg bisa dibatalkan lewat liveWakers. */
function liveSleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    let id = 0
    let done = false
    const finish = (): void => {
      if (done) return
      done = true
      window.clearTimeout(id)
      liveWakers = liveWakers.filter((w) => w !== finish)
      resolve()
    }
    id = window.setTimeout(finish, ms)
    liveWakers.push(finish)
  })
}

/** Scroll pelan ke bawah hanya bila halaman lebih tinggi dari layar.
    true = sampai bawah; false = muat 1 layar / dibatalkan. */
function liveScrollBottom(gen: number): Promise<boolean> {
  const el = document.scrollingElement
  if (!el) return Promise.resolve(false)
  const dist = el.scrollHeight - el.clientHeight
  if (dist <= 4) return Promise.resolve(false)
  const start = el.scrollTop
  const dur = Math.min(LIVE_SCROLL_MAX, Math.max(3000, ((dist - start) / LIVE_SPEED) * 1000))
  return new Promise((resolve) => {
    let done = false
    const canceler = (): void => finish(false)
    const finish = (ok: boolean): void => {
      if (done) return
      done = true
      if (liveRaf) {
        cancelAnimationFrame(liveRaf)
        liveRaf = 0
      }
      liveWakers = liveWakers.filter((w) => w !== canceler)
      resolve(ok)
    }
    liveWakers.push(canceler)
    const t0 = performance.now()
    const step = (t: number): void => {
      if (!liveMode.value || gen !== liveGen) {
        finish(false)
        return
      }
      const p = Math.min(1, (t - t0) / dur)
      // easeInOutQuad: start/stop halus, tengah paling cepat
      const e = p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2
      el.scrollTop = start + (dist - start) * e
      if (p < 1) liveRaf = requestAnimationFrame(step)
      else finish(true)
    }
    liveRaf = requestAnimationFrame(step)
  })
}

async function liveLoop(gen: number): Promise<void> {
  const alive = (): boolean => liveMode.value && gen === liveGen
  while (alive()) {
    await liveSleep(LIVE_DWELL)
    if (!alive()) return
    const scrolled = await liveScrollBottom(gen)
    if (!alive()) return
    if (scrolled) {
      await liveSleep(LIVE_TAIL)
      if (!alive()) return
    }
    // Slide terakhir wrap ke pertama -> carousel looping
    gotoSlide(slideIdx.value >= PRESENT_SLIDES.length - 1 ? 0 : slideIdx.value + 1)
    autoOpenDetails() // slide baru: "More details" dibuka otomatis saat data siap
  }
}

/* ==========================================================================
   Saat LIVE, "More details" tiap slide dipencet otomatis (tabel data ikut
   tampil di deck otomatis). Polling ringan: tombol baru ada setelah fetch
   selesai -> klik begitu muncul; berhenti saat semua sudah terbuka / data
   yakin tidak punya tombol / live dimatikan.
   ========================================================================== */
let detPoll = 0
function autoOpenDetails(): void {
  window.clearInterval(detPoll)
  if (!liveMode.value || !isPresent.value) return
  // Poll terus selama Live (ringan: cuma cek aria-expanded lalu klik false).
  // Jangan berhenti saat "semua sudah terbuka": DOM slide lama masih ada saat
  // transisi, poll harus tetap hidup sampai tombol slide BARU muncul.
  detPoll = window.setInterval(() => {
    if (!liveMode.value || !isPresent.value) {
      window.clearInterval(detPoll)
      return
    }
    document.querySelectorAll<HTMLButtonElement>('.main .details-btn').forEach((b) => {
      if (b.getAttribute('aria-expanded') !== 'true') b.click()
    })
  }, 350)
}

/** Toggle Live Mode. Matikan = batalkan timer/scroll loop yg sedang jalan. */
export function setLive(on: boolean): void {
  if (liveMode.value === on) return
  liveMode.value = on
  liveGen += 1
  const pending = liveWakers
  liveWakers = []
  pending.forEach((w) => w()) // resolve promise lama -> loop lama keluar di cek
  if (on) {
    autoOpenDetails() // slide pertama saat Live dinyalakan
    void liveLoop(liveGen)
  }
}

export async function enterPresent(): Promise<void> {
  if (isPresent.value) return
  isPresent.value = true
  document.body.classList.add('present-mode')
  // Sinkron arah transisi utk navigasi di luar gotoSlide (back/forward browser):
  // dipasang sekali di sini agar tidak kena siklus import router.ts di top-level.
  if (!dirHooked) {
    dirHooked = true
    router.afterEach((to, from) => {
      if (!isPresent.value) return
      const a = slideIndexOf(from.path, from.query.jenis)
      const b = slideIndexOf(to.path, to.query.jenis)
      if (a >= 0 && b >= 0 && a !== b) slideDir.value = b > a ? 'fwd' : 'back'
    })
  }
  try {
    if (!document.fullscreenElement && typeof document.documentElement.requestFullscreen === 'function') {
      await document.documentElement.requestFullscreen({ navigationUI: 'hide' })
    }
  } catch {
    /* ditolak policy / tidak didukung -> biarkan, CSS fallback sudah aktif */
  }
}
let dirHooked = false

export function exitPresent(): void {
  if (!isPresent.value) return
  setLive(false) // carousel berhenti saat keluar present (jg lewat Esc/exit fullscreen)
  isPresent.value = false
  document.body.classList.remove('present-mode')
  if (document.fullscreenElement) {
    document.exitFullscreen().catch(() => {})
  }
}

export function togglePresent(): void {
  if (isPresent.value) exitPresent()
  else void enterPresent()
}

/* Sinkron state bila user keluar dari fullscreen sendiri (Esc dsb.) */
document.addEventListener('fullscreenchange', () => {
  if (!document.fullscreenElement && isPresent.value) exitPresent()
})
/* Esc = keluar present (fallback non-fullscreen / native);
   panah kiri/kanan = slide prev/next di SEMUA menu (deck lintas menu).
   Space/PgUp sengaja TIDAK dipakai: bentrok dgn scroll konten panjang &
   tombol fokus. Lewati saat fokus di form control (panah dipakai utk pilih
   opsi select). */
document.addEventListener('keydown', (e) => {
  if (!isPresent.value) return
  if (e.key === 'Escape') {
    if (!document.fullscreenElement) exitPresent()
    return
  }
  const tag = (e.target as HTMLElement | null)?.tagName
  if (tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return
  if (e.key === 'ArrowRight') {
    e.preventDefault()
    nextSlide()
  } else if (e.key === 'ArrowLeft') {
    e.preventDefault()
    prevSlide()
  }
})
