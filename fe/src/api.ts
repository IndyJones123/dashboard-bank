import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000',
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
