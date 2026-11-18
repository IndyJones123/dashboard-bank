import { reactive, ref, watch } from 'vue'

/* ==========================================================================
   Mode Live Present: 'biasa' | 'cinematic'.
   - biasa     : Live seperti semula (halaman normal, scroll pelan, ganti slide)
   - cinematic : seluruh tur Live di panggung sinematik (CinematicStage.vue).
                 Tiap halaman diputar sbg rangkaian adegan: pembuka (judul +
                 angka utama) lalu 1 adegan per panel data halaman itu; sesudah
                 adegan terakhir Live pindah ke halaman berikutnya. Panggung
                 tetap terbuka antar halaman (tidak kembali ke tampilan biasa).
   Angka = DOM halaman asli (hasil query yg sama), tidak ada angka buatan.
   Modul ini sengaja TIDAK meng-import present.ts (hindari siklus import).
   ========================================================================== */

export type PresentStyle = 'biasa' | 'cinematic'
const KEY = 'present_style'

function load(): PresentStyle {
  try {
    return localStorage.getItem(KEY) === 'biasa' ? 'biasa' : 'cinematic'
  } catch {
    return 'cinematic'
  }
}

export const presentStyle = ref<PresentStyle>(load())
watch(presentStyle, (v) => {
  try {
    localStorage.setItem(KEY, v)
  } catch {
    /* storage diblok: pilihan berlaku sesi ini saja */
  }
})

/** run naik tiap halaman baru diputar; active = panggung sedang terbuka. */
export const cinema = reactive({ run: 0, active: false })

export type PageResult = 'done' | 'stop'
let resolvePage: ((r: PageResult) => void) | null = null

/** Putar semua adegan halaman saat ini. 'done' = adegan habis (Live boleh
    pindah halaman); 'stop' = disela (navigasi manual / mode diganti / berhenti). */
export function playCinematicPage(): Promise<PageResult> {
  resolvePage?.('stop')
  cinema.active = true
  cinema.run += 1
  return new Promise((r) => {
    resolvePage = r
  })
}

/** Dipanggil panggung sesudah adegan terakhir halaman ini. */
export function pageDone(): void {
  const r = resolvePage
  resolvePage = null
  r?.('done')
}

/** Sela halaman yang sedang diputar tanpa menutup panggung (navigasi manual). */
export function interruptCinematic(): void {
  const r = resolvePage
  resolvePage = null
  r?.('stop')
}

/** Tutup panggung (Live mati, mode Biasa, atau keluar Present). */
export function stopCinematic(): void {
  cinema.active = false
  interruptCinematic()
}
