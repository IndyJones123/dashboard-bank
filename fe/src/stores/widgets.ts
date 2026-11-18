import { computed, ref, unref, type MaybeRef } from 'vue'
import api from '../api'
import { isLoggedIn } from './auth'

/* ==========================================================================
   Layout widget per halaman (CMS tab "Widget Setting").
   Registry di bawah = daftar widget + layout default tiap halaman. Admin
   menyimpan urutan, visibilitas, dan lebar (span dari 12 kolom) lewat
   PUT /api/widgets; semua pengguna (tamu & Present Mode juga) memakai
   layout tersimpan lewat GET /api/widgets saat boot.
   Widget yang disembunyikan tidak dirender; baris yang jadi tidak penuh
   dilebarkan otomatis (packRows) supaya tidak ada lubang di grid.
   ========================================================================== */

export type WidgetKind = 'angka' | 'ringkasan' | 'grafik' | 'tabel' | 'info'

export interface WidgetDef {
  id: string
  label: string
  kind: WidgetKind
  span: number
  /** Boleh dilihat tamu (tanpa login) secara default. */
  guest?: boolean
}

export interface PageDef {
  id: string
  label: string
  /** Rute utk tombol "Lihat halaman" di CMS. */
  to: string
  widgets: WidgetDef[]
}

export interface WidgetItem {
  id: string
  visible: boolean
  span: number
  /** true = tampil juga untuk tamu (tanpa login); false = perlu login. */
  guest: boolean
}

export type WidgetPages = Record<string, WidgetItem[]>

export const WIDGET_SPANS = [
  { span: 12, label: 'Penuh' },
  { span: 8, label: '2/3' },
  { span: 7, label: 'Lebar' },
  { span: 6, label: 'Separuh' },
  { span: 5, label: 'Sedang' },
  { span: 4, label: '1/3' },
] as const

const glWidgets = (total: string): WidgetDef[] => [
  { id: 'angka-utama', label: total, kind: 'angka', span: 7 },
  { id: 'tren-singkat', label: 'Sparkline tren', kind: 'ringkasan', span: 5 },
  { id: 'konsolidasi', label: 'Konsolidasi semua cabang', kind: 'grafik', span: 12 },
  { id: 'per-kantor', label: 'Rincian per kantor', kind: 'grafik', span: 12 },
]

/** Urutan halaman = urutan deck Present Mode. */
export const WIDGET_PAGES: PageDef[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    to: '/',
    widgets: [
      // guest: true = perilaku lama (ringkasan dashboard publik); sama dgn
      // WIDGET_GUEST_DEFAULT di be/app.py
      { id: 'total-simpanan', label: 'Total Simpanan', kind: 'angka', span: 7, guest: true },
      { id: 'ringkasan', label: 'Nasabah, transaksi, kredit', kind: 'ringkasan', span: 5, guest: true },
      { id: 'arus-kas', label: 'Arus kas 6 bulan', kind: 'grafik', span: 8, guest: true },
      { id: 'komposisi', label: 'Komposisi dana', kind: 'grafik', span: 4, guest: true },
      { id: 'transaksi', label: 'Transaksi terbaru', kind: 'tabel', span: 5, guest: true },
      { id: 'insight', label: 'Insight nasabah prioritas', kind: 'tabel', span: 7 },
    ],
  },
  { id: 'reports-aset', label: 'Laporan Aset', to: '/reports?jenis=aset', widgets: glWidgets('Total aset') },
  { id: 'reports-labarugi', label: 'Laporan Laba Rugi', to: '/reports?jenis=labarugi', widgets: glWidgets('Total laba rugi') },
  {
    id: 'reports-harian',
    label: 'Laporan Keuangan Harian',
    to: '/reports?jenis=harian',
    widgets: [
      { id: 'angka-utama', label: 'Total OS Pokok', kind: 'angka', span: 7 },
      { id: 'ringkasan', label: 'Kas, bank, NPF, laba', kind: 'ringkasan', span: 5 },
      { id: 'perincian', label: 'Perincian harian', kind: 'tabel', span: 12 },
    ],
  },
  {
    id: 'reports-dpk',
    label: 'Laporan DPK',
    to: '/reports?jenis=dpk',
    widgets: [
      { id: 'angka-utama', label: 'Total DPK', kind: 'angka', span: 7 },
      { id: 'ringkasan', label: 'Tabungan dan deposito', kind: 'ringkasan', span: 5 },
      { id: 'grafik-tabungan', label: 'Grafik DPK Tabungan', kind: 'grafik', span: 12 },
      { id: 'grafik-deposito', label: 'Grafik DPK Deposito', kind: 'grafik', span: 12 },
    ],
  },
  {
    id: 'reports-piutang',
    label: 'Laporan Piutang',
    to: '/reports?jenis=piutang',
    widgets: [
      { id: 'angka-utama', label: 'Posisi piutang', kind: 'angka', span: 7 },
      { id: 'ringkasan', label: 'Pertumbuhan dan selisih', kind: 'ringkasan', span: 5 },
      { id: 'grafik-total', label: 'Grafik total piutang', kind: 'grafik', span: 12 },
      { id: 'grafik-golongan', label: 'Grafik per golongan', kind: 'grafik', span: 12 },
    ],
  },
  {
    id: 'likuiditas',
    label: 'Likuiditas',
    to: '/likuiditas',
    widgets: [{ id: 'info', label: 'Informasi halaman', kind: 'info', span: 12 }],
  },
  {
    id: 'pembiayaan-saldo',
    label: 'Pembiayaan: List Saldo',
    to: '/pembiayaan/saldo',
    widgets: [
      { id: 'angka-utama', label: 'Outstanding pembiayaan', kind: 'angka', span: 7 },
      { id: 'ringkasan', label: 'NPF dan realisasi', kind: 'ringkasan', span: 5 },
      { id: 'kolektibilitas', label: 'Kolektibilitas & NPF', kind: 'tabel', span: 12 },
      { id: 'realisasi', label: 'Realisasi pembiayaan', kind: 'tabel', span: 12 },
      { id: 'os-bulanan', label: 'Outstanding per bulan', kind: 'grafik', span: 12 },
    ],
  },
  {
    id: 'pembiayaan-tagihan',
    label: 'Pembiayaan: Tagihan & Tunggakan',
    to: '/pembiayaan/tagihan',
    widgets: [
      { id: 'angka-utama', label: 'Total tunggakan', kind: 'angka', span: 7 },
      { id: 'ringkasan', label: 'Pokok, margin, DPD > 90', kind: 'ringkasan', span: 5 },
      { id: 'dpd', label: 'Umur tunggakan (DPD)', kind: 'tabel', span: 12 },
      { id: 'tunggakan', label: 'Tunggakan per kantor/AO', kind: 'tabel', span: 12 },
      { id: 'nasabah', label: 'Nasabah menunggak', kind: 'tabel', span: 12 },
    ],
  },
]

const PAGE_BY_ID = new Map(WIDGET_PAGES.map((p) => [p.id, p]))
const SPAN_SET = new Set<number>(WIDGET_SPANS.map((s) => s.span))

export function pageDef(pageId: string): PageDef | undefined {
  return PAGE_BY_ID.get(pageId)
}

export function defaultItems(pageId: string): WidgetItem[] {
  return (pageDef(pageId)?.widgets ?? []).map((w) => ({ id: w.id, visible: true, span: w.span, guest: !!w.guest }))
}

/** Gabung layout tersimpan dgn registry: id yg tak dikenal dibuang, widget
    baru (belum pernah disimpan) ditambahkan di posisi default-nya. */
export function mergeItems(pageId: string, saved: WidgetItem[] | undefined): WidgetItem[] {
  const defs = defaultItems(pageId)
  if (!saved?.length) return defs
  const byId = new Map(defs.map((d) => [d.id, d]))
  const out = saved
    .filter((s) => byId.has(s.id))
    .map((s) => ({
      id: s.id,
      visible: s.visible !== false,
      span: SPAN_SET.has(s.span) ? s.span : 12,
      guest: typeof s.guest === 'boolean' ? s.guest : byId.get(s.id)!.guest,
    }))
  defs.forEach((d, i) => {
    if (out.some((o) => o.id === d.id)) return
    out.splice(Math.min(i, out.length), 0, d)
  })
  return out
}

/** Lebar efektif: susun widget tampil per baris 12 kolom; sisa kolom di
    ujung baris diberikan ke widget terakhir baris itu (tak ada lubang). */
export function packRows(items: WidgetItem[]): Map<string, number> {
  const out = new Map<string, number>()
  let row: WidgetItem[] = []
  let used = 0
  const close = (): void => {
    if (!row.length) return
    const last = row[row.length - 1]
    out.set(last.id, last.span + (12 - used))
    row = []
    used = 0
  }
  for (const it of items) {
    if (!it.visible) continue
    if (used + it.span > 12) close()
    row.push(it)
    out.set(it.id, it.span)
    used += it.span
  }
  close()
  return out
}

/** Layout tersimpan (dipakai semua halaman). */
export const savedPages = ref<WidgetPages>({})

/* ---- Pratinjau langsung (CMS Widget Setting) ----
   CMS memuat halaman asli di iframe dgn ?wpreview=1, lalu mengirim draft
   layout lewat postMessage. Di dalam iframe, draft menggantikan layout
   tersimpan (hanya di iframe itu; tidak pernah disimpan). */
export const PREVIEW_PARAM = 'wpreview'
export const PREVIEW_MSG = 'widget-preview'
export const isWidgetPreview = new URLSearchParams(window.location.search).has(PREVIEW_PARAM)
export const previewPages = ref<WidgetPages | null>(null)
/** Pratinjau "lihat sebagai tamu" (null = ikut status login asli). */
export const previewAsGuest = ref<boolean | null>(null)

if (isWidgetPreview) {
  document.body.classList.add('widget-preview')
  window.addEventListener('message', (e: MessageEvent) => {
    if (e.origin !== window.location.origin) return
    const d = e.data as { type?: string; pages?: WidgetPages; asGuest?: boolean } | null
    if (d?.type !== PREVIEW_MSG) return
    if (d.pages && typeof d.pages === 'object') previewPages.value = d.pages
    if (typeof d.asGuest === 'boolean') previewAsGuest.value = d.asGuest
  })
  // Beri tahu CMS bahwa iframe siap menerima draft
  window.parent?.postMessage({ type: `${PREVIEW_MSG}-ready` }, window.location.origin)
}

/** Muat layout saat boot (publik; gagal -> layout default). */
export async function loadWidgets(): Promise<void> {
  try {
    const { data } = await api.get('/api/widgets')
    if (data?.pages && typeof data.pages === 'object') savedPages.value = data.pages as WidgetPages
  } catch {
    /* BE mati: layout default */
  }
}

/** Simpan layout semua halaman (admin); terapkan hasil server. */
export async function saveWidgets(pages: WidgetPages): Promise<void> {
  const { data } = await api.put('/api/widgets', { pages })
  savedPages.value = (data?.pages ?? pages) as WidgetPages
}

/** Penonton saat ini tamu? (pratinjau CMS bisa memaksa sudut pandang tamu) */
export const viewerIsGuest = computed(() => previewAsGuest.value ?? !isLoggedIn.value)

function pageItems(pageId: string): WidgetItem[] {
  return mergeItems(pageId, (previewPages.value ?? savedPages.value)[pageId])
}

/** Halaman punya minimal 1 widget tampil yang boleh dilihat tamu. */
export function pageGuestOK(pageId: string): boolean {
  return pageItems(pageId).some((it) => it.visible && it.guest)
}

/** Penonton saat ini boleh membuka halaman ini (login, atau tamu + ada widget tamu). */
export function pageViewable(pageId: string): boolean {
  return !viewerIsGuest.value || pageGuestOK(pageId)
}

/** Dipakai tiap halaman: show(id) utk v-if, style(id) utk urutan & lebar.
    Widget "perlu login" dianggap tersembunyi bagi tamu (grid ikut merapat).
    Id di luar registry (mis. chart baru dari data) tetap tampil di akhir. */
export function useWidgets(pageId: MaybeRef<string>) {
  const items = computed(() =>
    pageItems(unref(pageId)).map((it) => ({
      ...it,
      visible: it.visible && (!viewerIsGuest.value || it.guest),
    })),
  )
  const spans = computed(() => packRows(items.value))
  const index = computed(() => new Map(items.value.map((it) => [it.id, it])))
  const order = computed(() => new Map(items.value.map((it, i) => [it.id, i])))
  const anyVisible = computed(() => items.value.some((it) => it.visible))
  /** Jumlah widget yang tampil utk login tapi disembunyikan dari tamu. */
  const lockedCount = computed(() =>
    viewerIsGuest.value ? pageItems(unref(pageId)).filter((it) => it.visible && !it.guest).length : 0,
  )
  return {
    lockedCount,
    show: (id: string): boolean => index.value.get(id)?.visible ?? true,
    style: (id: string): Record<string, string | number> => ({
      order: order.value.get(id) ?? 99,
      '--span': spans.value.get(id) ?? 12,
    }),
    anyVisible,
  }
}
