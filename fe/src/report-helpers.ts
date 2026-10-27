/* Helper bersama utk tampilan laporan keuangan (ReportsHarian / ReportsDpk /
   ReportsPiutang / tabel MoreDetails di Reports). Konsisten dgn util di Reports.vue. */
import { formatRupiah } from './api'

/** `detail` dari FastAPI (mis. 503 "Database tidak terjangkau …") bila ada. */
export function apiErrText(e: unknown, fallback: string): string {
  const d = (e as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail
  return typeof d === 'string' && d ? d : fallback
}

const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']

/** '01' -> 'Jan' (fallback: nilai mentah). */
export function shortMonth(bln: string): string {
  const i = Number(bln)
  return MONTH_SHORT[i - 1] ?? bln
}

/** Daftar tahun utk filter: n tahun terakhir (default s/d tahun berjalan), urut naik. */
export function recentYears(n = 4): string[] {
  const y = new Date().getFullYear()
  return Array.from({ length: n }, (_, i) => String(y - i)).reverse()
}

/** Jenis laporan keuangan, urut spt dropdown & urutan slide Present Mode. */
export const REPORT_KINDS = ['aset', 'labarugi', 'harian', 'dpk', 'piutang'] as const

/** Label tiap jenis laporan (dipakai Reports.vue & deck slide Present Mode). */
export const REPORT_KIND_LABELS: Record<string, string> = {
  aset: 'Laporan Aset',
  labarugi: 'Laporan Laba Rugi',
  harian: 'Laporan Keuangan Harian',
  dpk: 'Laporan DPK',
  piutang: 'Laporan Piutang',
}

/** Palet warna kantor utk chart, cukup kontras di kedua tema (bukan text-500). */
export const KANTOR_PALETTE = [
  '#1e5fa3', '#2563eb', '#059669', '#b45309', '#7c3aed',
  '#dc2626', '#0891b2', '#be185d', '#4d7c0f',
]

/** Warna kantor dari daftar kdloc terurut (indentik antar laporan). */
export function kantorColor(kdloc: string, sortedKantors: string[]): string {
  const i = sortedKantors.indexOf(kdloc)
  return KANTOR_PALETTE[(i < 0 ? 0 : i) % KANTOR_PALETTE.length]
}

/** Format pertumbuhan % antar periode; null -> '–'. */
export function growthPct(v: number | null | undefined): string {
  return v == null ? '–' : `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`
}

/** Nilai ringkas utk tabel terperinci (MoreDetails): T = triliun, M = miliar,
    jt = juta; < 1 jt tetap rupiah penuh. Pasangkan :title="formatRupiah(v)"
    di selnya supaya hover menampilkan nilai penuh. */
export function formatRpSingkat(v: number | string | null | undefined): string {
  if (v === null || v === undefined) return '–'
  const num = typeof v === 'string' ? Number(v) : v
  if (Number.isNaN(num)) return String(v)
  const a = Math.abs(num)
  const n = (x: number, d: number): string =>
    x.toLocaleString('id-ID', { maximumFractionDigits: d })
  if (a >= 1e12) return `Rp ${n(num / 1e12, 2)} T`
  if (a >= 1e9) return `Rp ${n(num / 1e9, 2)} M`
  if (a >= 1e6) return `Rp ${n(num / 1e6, 1)} jt`
  return formatRupiah(num)
}
