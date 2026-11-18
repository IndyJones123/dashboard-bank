import { ref } from 'vue'
import api from '../api'

/* ==========================================================================
   Tema global (CMS palet fitlink): 9 token hex dari GET/PUT /api/theme
   diterapkan ke :root secara runtime (custom property). Var TURUNAN
   (ring/soft/fill/deret rgba border) dihitung di sini: admin cukup memilih
   9 warna solid, konsistensi otomatis. Default = palet fitlink identik
   dgn :root fe/src/style.css (sumber kebenaran visual).
   ========================================================================== */

export const THEME_TOKENS = [
  { key: 'bg', label: 'Canvas (latar halaman)' },
  { key: 'surface', label: 'Kartu / panel' },
  { key: 'surface-2', label: 'Surface-2 (blok bantu)' },
  { key: 'ink', label: 'Teks utama (ink)' },
  { key: 'muted', label: 'Teks muted' },
  { key: 'primary', label: 'Primary (brand)' },
  { key: 'accent', label: 'Aksen (seri kedua grafik)' },
  { key: 'green', label: 'Hijau (positif)' },
  { key: 'red', label: 'Merah (risiko)' },
] as const

export type ThemeKey = (typeof THEME_TOKENS)[number]['key']
export type ThemeTokens = Record<ThemeKey, string>

export const DEFAULT_THEME: ThemeTokens = {
  bg: '#f5f6f3',
  surface: '#ffffff',
  'surface-2': '#eff1ed',
  ink: '#15201b',
  muted: '#5d6963',
  primary: '#0f5c4e',
  accent: '#b08534',
  green: '#2e8b57',
  red: '#c0392b',
}

/** Preset "Biru fitlink": palet default sebelum redesain Ledger Hijau. */
export const FITLINK_THEME: ThemeTokens = {
  bg: '#f8fafc',
  surface: '#ffffff',
  'surface-2': '#f2f4f6',
  ink: '#0f172a',
  muted: '#475569',
  primary: '#1e5fa3',
  accent: '#4cb5ff',
  green: '#22c55e',
  red: '#dc2626',
}

/** Preset "Navy legacy": palet sebelum redesain fitlink (dari git HEAD). */
export const LEGACY_THEME: ThemeTokens = {
  bg: '#f8fafc',
  surface: '#ffffff',
  'surface-2': '#f2f4f6',
  ink: '#191c1e',
  muted: '#475569',
  primary: '#0a192f',
  accent: '#059669',
  green: '#059669',
  red: '#dc2626',
}

export const HEX6 = /^#[0-9a-fA-F]{6}$/

/** Tema yg sedang terpasang di :root (dipakai preview lokal editor). */
export const applied = ref<ThemeTokens>({ ...DEFAULT_THEME })

function rgba(hex: string, a: number): string {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`
}

/** Gelapkan (f<0) / terangkan (f>0) hex solid: bahan var turunan. */
function shade(hex: string, f: number): string {
  const n = parseInt(hex.slice(1), 16)
  const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) =>
    Math.round(f < 0 ? c * (1 + f) : c + (255 - c) * f),
  )
  return `#${ch.map((c) => c.toString(16).padStart(2, '0')).join('')}`
}

/** Terapkan 9 token + var turunan ke :root (hasil load & preview editor). */
export function applyTheme(tokens: Partial<ThemeTokens>): void {
  const t: ThemeTokens = { ...DEFAULT_THEME, ...tokens }
  const root = document.documentElement
  for (const { key } of THEME_TOKENS) {
    if (HEX6.test(t[key])) root.style.setProperty(`--${key}`, t[key])
  }
  // Turunan primary (gelap utk hover, tint/ring utk kontrol)
  root.style.setProperty('--primary-dark', shade(t.primary, -0.22))
  root.style.setProperty('--primary-10', rgba(t.primary, 0.08))
  root.style.setProperty('--primary-40', rgba(t.primary, 0.32))
  root.style.setProperty('--primary-ring', rgba(t.primary, 0.28))
  // Turunan green/red (chip, fill batang, garis, focus di permukaan gelap)
  root.style.setProperty('--green-dark', shade(t.green, -0.55))
  root.style.setProperty('--green-fill', rgba(t.green, 0.85))
  root.style.setProperty('--green-soft', rgba(t.green, 0.12))
  root.style.setProperty('--green-line', rgba(t.green, 0.32))
  root.style.setProperty('--red-bg', rgba(t.red, 0.1))
  root.style.setProperty('--red-dark', shade(t.red, -0.2))
  // Turunan ink: teks + hairline struktural dari keluarga ink
  root.style.setProperty('--text', t.ink)
  root.style.setProperty('--muted-2', shade(t.muted, -0.35))
  root.style.setProperty('--border', rgba(t.ink, 0.07))
  root.style.setProperty('--border-strong', rgba(t.ink, 0.11))
  root.style.setProperty('--ink-4', rgba(t.ink, 0.035))
  root.style.setProperty('--ink-10', rgba(t.ink, 0.08))
  root.style.setProperty('--ink-16', rgba(t.ink, 0.15))
  // Turunan surface-2 -> surface-3 / canvas-dim (permukaan semakin tua)
  root.style.setProperty('--surface-3', shade(t['surface-2'], -0.04))
  root.style.setProperty('--canvas-dim', shade(t['surface-2'], -0.16))
  applied.value = t
}

/** Muat tema global saat boot (publik; gagal -> palet default :root berlaku). */
export async function loadTheme(): Promise<void> {
  try {
    const { data } = await api.get('/api/theme')
    if (data?.tokens) applyTheme(data.tokens as Partial<ThemeTokens>)
  } catch {
    /* BE mati / jaringan: palet default di CSS sudah benar */
  }
}

/** Simpan tema global (admin): server memvalidasi ulang & mengembalikan
    merged; bila sukses, terapkan hasil server (bukan draft lokal). */
export async function saveTheme(tokens: ThemeTokens): Promise<void> {
  const { data } = await api.put('/api/theme', { tokens })
  if (data?.tokens) applyTheme(data.tokens as Partial<ThemeTokens>)
}

/** Kontras WCAG (ratio) antar2 hex: guard editor. */
export function contrastRatio(a: string, b: string): number {
  const lum = (hex: string): number => {
    const n = parseInt(hex.slice(1), 16)
    const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((c) => {
      const s = c / 255
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
    })
    return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
  }
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x)
  return (l1 + 0.05) / (l2 + 0.05)
}
