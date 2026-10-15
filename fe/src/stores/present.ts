import { ref } from 'vue'

/* ==========================================================================
   PRESENT MODE — mode fullscreen untuk slideshow presentasi.
   Tombol "Present Mode" di topbar memanggil enterPresent():
     1. Fullscreen API diaktifkan (documentElement) → layar penuh tanpa chrome
     2. class `present-mode` dipasang di <body> → topbar/sidebar disembunyikan
        CSS, konten melebar (max-width 1600px) — slide jadi bersih.
   Kalau Fullscreen API ditolak/tidak tersedia (mis. iOS/iPadOS Safari),
   class CSS tetap dipasang → tampilan present tetap rapi walau chrome
   browser masih terlihat (fallback).
   Keluar: tombol mengambang "Keluar Present", Esc (native fullscreen /
   fallback), atau fullscreenchange (user keluar sendiri) → state disinkronkan.
   ========================================================================== */

export const isPresent = ref(false)

export async function enterPresent(): Promise<void> {
  if (isPresent.value) return
  isPresent.value = true
  document.body.classList.add('present-mode')
  try {
    if (!document.fullscreenElement && typeof document.documentElement.requestFullscreen === 'function') {
      await document.documentElement.requestFullscreen({ navigationUI: 'hide' })
    }
  } catch {
    /* ditolak policy / tidak didukung → biarkan, CSS fallback sudah aktif */
  }
}

export function exitPresent(): void {
  if (!isPresent.value) return
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
/* Esc saat fallback non-fullscreen (class aktif, API tidak jalan) */
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && isPresent.value && !document.fullscreenElement) exitPresent()
})
