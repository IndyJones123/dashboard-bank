import axios from 'axios'

const api = axios.create({
  // Dev tanpa VITE_API_BASE_URL: path relatif, diteruskan proxy Vite (vite.config.ts).
  baseURL: import.meta.env.VITE_API_BASE_URL ?? (import.meta.env.DEV ? '' : 'http://localhost:8000'),
  timeout: 10000,
})

// Sisipkan token otomatis bila ada
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('bank_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

export default api

export function formatRupiah(n: number | string | null | undefined): string {
  // null/undefined dari API: placeholder '–' (bukan 'Rp 0' / crash; Number.isNaN(null) = false)
  if (n === null || n === undefined) return '–'
  const num = typeof n === 'string' ? Number(n) : n
  if (Number.isNaN(num)) return String(n)
  return 'Rp ' + num.toLocaleString('id-ID')
}

/* Angka > 11 digit (>= 100 miliar) terlalu panjang dibaca: ditampilkan
   ringkas dalam M (miliar) dan nilai lengkapnya lewat tooltip (RpValue.vue). */
const LONG_MIN = 1e11

function toNum(n: number | string | null | undefined): number | null {
  if (n === null || n === undefined || n === '') return null
  const num = typeof n === 'string' ? Number(n) : n
  return Number.isFinite(num) ? num : null
}

/** true bila bagian bulat nilai lebih dari 11 digit. */
export function isLongNum(n: number | string | null | undefined): boolean {
  const num = toNum(n)
  return num !== null && Math.abs(Math.round(num)) >= LONG_MIN
}

/** Bilangan bulat penuh tanpa "Rp" (kolom tabel Pembiayaan). */
export function formatInt(n: number | string | null | undefined): string {
  const num = toNum(n)
  return num === null ? (n == null || n === '' ? '–' : String(n)) : Math.round(num).toLocaleString('id-ID')
}

/** > 11 digit -> "Rp 1.420,6 M"; selain itu nilai penuh. `bare` = tanpa "Rp". */
export function formatRpM(n: number | string | null | undefined, bare = false): string {
  const num = toNum(n)
  if (num === null || !isLongNum(num)) return bare ? formatInt(n) : formatRupiah(n)
  const m = (num / 1e9).toLocaleString('id-ID', { maximumFractionDigits: 2 })
  return bare ? `${m} M` : `Rp ${m} M`
}
