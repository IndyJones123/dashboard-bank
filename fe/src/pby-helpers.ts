/* Helper bersama halaman Pembiayaan (List Saldo / Tagihan & Tunggakan). */
import api from './api'
import { shortMonth } from './report-helpers'

export type Row = Record<string, unknown>

/** Warna ordinal tingkat risiko (lancar -> macet / DPD ringan -> berat).
    Encoding data, sengaja lepas dari token tema CMS. */
export const RISK_COLORS = ['#2e7d4f', '#8fae2f', '#d99a14', '#dd6b1d', '#c0392b']

/** Kolektibilitas: kolom coll1..coll5 hasil query NPF. */
export const KOL = [
  { key: 'coll1', label: 'Kol 1', name: 'Lancar' },
  { key: 'coll2', label: 'Kol 2', name: 'Dalam Perhatian Khusus' },
  { key: 'coll3', label: 'Kol 3', name: 'Kurang Lancar' },
  { key: 'coll4', label: 'Kol 4', name: 'Diragukan' },
  { key: 'coll5', label: 'Kol 5', name: 'Macet' },
] as const

/** Bucket DPD: pasangan kolom jumlah (Q) & outstanding (D) query DPD Revisi. */
export const DPD = [
  { q: 'Q1', d: 'D000_030', label: '0–30 hari' },
  { q: 'Q2', d: 'D031_090', label: '31–90 hari' },
  { q: 'Q3', d: 'D091_180', label: '91–180 hari' },
  { q: 'Q4', d: 'D181_360', label: '181–360 hari' },
  { q: 'Q5', d: 'D361_999', label: '> 360 hari' },
] as const

export const num = (v: unknown): number => Number(v) || 0
export const sumOf = (rows: Row[], key: string): number => rows.reduce((s, r) => s + num(r[key]), 0)

/** NPF % = (Kol 3 + Kol 4 + Kol 5) / OS × 100 — rumus yang sama dgn query. */
export function npfOf(rows: Row[]): number | null {
  const os = sumOf(rows, 'os')
  if (!os) return null
  return ((sumOf(rows, 'coll3') + sumOf(rows, 'coll4') + sumOf(rows, 'coll5')) / os) * 100
}

/** Bulan sebelum `base` ('YYYY-MM-DD', default hari ini) sbg 'YYYY-MM'. */
export function lastMonth(base?: string | null): string {
  const d = base ? new Date(`${base}T00:00:00`) : new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() - 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** 'YYYY-MM' -> 'YYYYMM' (format @periode query). */
export const toPeriode = (ym: string): string => ym.replace('-', '')

/** 'YYYY-MM' -> 'Mar 2025'. */
export function monthLabel(ym: string): string {
  const [y, m] = ym.split('-')
  return `${shortMonth(m ?? '')} ${y ?? ''}`
}

export const pctText = (v: number | null): string =>
  v == null ? '–' : `${v.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`

/** Tanggal sistem core banking (tabel Tanggal) — acuan query 'berjalan'.
    Di-cache per sesi halaman; gagal/kosong -> null (pakai kalender lokal). */
let tglPromise: Promise<string | null> | null = null
export function sysDate(): Promise<string | null> {
  tglPromise ??= api
    .get<{ tanggal: string | null }>('/api/pembiayaan/tanggal')
    .then((r) => r.data.tanggal ?? null)
    .catch(() => {
      tglPromise = null
      return null
    })
  return tglPromise
}

/** '2024-06-10' -> '10 Jun 2024'. */
export function dateLabel(iso: string): string {
  const [y, m, d] = iso.split('-')
  return `${Number(d)} ${shortMonth(m ?? '')} ${y}`
}

export const intText = (v: number): string => Math.round(v).toLocaleString('id-ID')
