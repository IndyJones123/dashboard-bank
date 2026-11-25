import { computed, reactive, watch, type Ref } from 'vue'
import api from './api'
import { apiErrText, KANTOR_PALETTE, shortMonth } from './report-helpers'
import { type Row, monthLabel, num, sumOf } from './pby-helpers'
import type { MonthSeries } from './views/PbyMonthBars.vue'
import type { PbyCol } from './views/PbyTable.vue'

/* Grafik pertumbuhan bulanan (Realisasi / NPF) List Saldo.
   Mode 'lokasi' = seri per produk + filter Cabang; mode 'ao' = seri per AO + filter AO. */

export type View = 'lokasi' | 'ao'
export const BLN = Array.from({ length: 12 }, (_, i) => `bln${String(i + 1).padStart(2, '0')}`)
const OTHER_COLOR = '#9aa3ad'
/** Batas seri AO di grafik; sisanya digabung jadi "Lainnya". */
const MAX_AO_SERIES = 8

/** Pilihan bulan: 24 bulan mundur dari `end` ('YYYY-MM'); yg pertama diberi `mark`. */
export function monthOpts(end: string, mark: string): { v: string; label: string }[] {
  const [y, m] = end.split('-').map(Number)
  return Array.from({ length: 24 }, (_, i) => {
    const d = new Date(y, m - 1 - i, 1)
    const v = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    return { v, label: i === 0 ? `${monthLabel(v)} (${mark})` : monthLabel(v) }
  })
}

/** Warna per id (urut id), konsisten antar grafik & kartu. */
export function colorsBy(rows: Row[], idKey: string): Map<string, string> {
  const ids = [...new Set(rows.map((r) => String(r[idKey])))].sort()
  return new Map(ids.map((k, i) => [k, KANTOR_PALETTE[i % KANTOR_PALETTE.length]]))
}

/** Baris bln01..bln12 -> seri grafik per `idKey`. `max` > 0: seri terbesar
    dipertahankan, sisanya digabung "Lainnya". */
export function toSeries(rows: Row[], idKey: string, nameKey: string, colors: Map<string, string>, max = 0): MonthSeries[] {
  const by = new Map<string, MonthSeries>()
  for (const r of rows) {
    const k = String(r[idKey])
    const s = by.get(k) ?? { key: k, label: String(r[nameKey] ?? k), color: colors.get(k) ?? KANTOR_PALETTE[0], values: BLN.map(() => 0) }
    BLN.forEach((b, i) => { s.values[i] += num(r[b]) })
    by.set(k, s)
  }
  const list = [...by.values()].sort((a, b) => a.key.localeCompare(b.key))
  if (!max || list.length <= max) return list
  const tot = (s: MonthSeries): number => s.values.reduce((t, v) => t + v, 0)
  const keep = new Set([...list].sort((a, b) => tot(b) - tot(a)).slice(0, max - 1).map((s) => s.key))
  const rest = list.filter((s) => !keep.has(s.key))
  return [
    ...list.filter((s) => keep.has(s.key)),
    {
      key: '__other', label: `Lainnya (${rest.length} AO)`, color: OTHER_COLOR,
      values: BLN.map((_, i) => rest.reduce((t, s) => t + s.values[i], 0)),
    },
  ]
}

/** Gabung baris per `idKey` (jumlah kolom bulanan). */
function mergeBy(rows: Row[], idKey: string, nameKey: string): Row[] {
  const by = new Map<string, Row>()
  for (const r of rows) {
    const k = String(r[idKey])
    const cur = by.get(k)
    if (!cur) by.set(k, { [idKey]: r[idKey], [nameKey]: r[nameKey], ...Object.fromEntries(BLN.map((b) => [b, num(r[b])])) })
    else for (const b of BLN) cur[b] = num(cur[b]) + num(r[b])
  }
  return [...by.values()]
}

export interface Opt { id: string; nama: string }

export function useTrend(o: {
  url: string
  view: Ref<View>
  /** Bulan default/terakhir yg bisa dipilih ('YYYY-MM'). */
  end: () => string
  mark: string
  /** Daftar kantor utk dropdown Cabang (mode lokasi). */
  kantors: () => Opt[]
  /** Warna AO (samakan dgn kartu AO). */
  aoColors: () => Map<string, string>
  errText: string
}) {
  const st = reactive({ bulan: o.end(), cabang: 'all', ao: 'all', loading: true, error: '', rows: [] as Row[], det: false })
  const months = computed(() => monthOpts(o.end(), o.mark))
  const year = computed(() => st.bulan.slice(0, 4))
  const upto = computed(() => Number(st.bulan.slice(5, 7)))
  const isAo = computed(() => o.view.value === 'ao')

  let seq = 0
  async function load(): Promise<void> {
    const my = ++seq
    const view = o.view.value
    st.loading = true
    st.error = ''
    try {
      const { data } = await api.get<Record<string, unknown>>(o.url, {
        params: { tahun: year.value, sampai: upto.value, view }, timeout: 120000,
      })
      if (my !== seq) return
      st.rows = (data[view] as Row[] | undefined) ?? []
    } catch (e) {
      if (my !== seq) return
      st.rows = []
      st.error = apiErrText(e, o.errText)
    } finally {
      if (my === seq) st.loading = false
    }
  }
  watch(o.view, () => { st.ao = 'all'; void load() })

  const aos = computed<Opt[]>(() =>
    isAo.value
      ? st.rows.map((r) => ({ id: String(r.kdaoh), nama: String(r.nmao || r.kdaoh) })).sort((a, b) => a.nama.localeCompare(b.nama))
      : [],
  )
  watch(aos, (list) => { if (st.ao !== 'all' && !list.some((a) => a.id === st.ao)) st.ao = 'all' })

  const filtered = computed(() => {
    if (isAo.value) return st.ao === 'all' ? st.rows : st.rows.filter((r) => String(r.kdaoh) === st.ao)
    return st.cabang === 'all' ? st.rows : st.rows.filter((r) => String(r.kdloc) === st.cabang)
  })
  const series = computed(() =>
    isAo.value
      ? toSeries(filtered.value, 'kdaoh', 'nmao', o.aoColors().size ? o.aoColors() : colorsBy(st.rows, 'kdaoh'), MAX_AO_SERIES)
      : toSeries(filtered.value, 'kdprd', 'nmprd', colorsBy(st.rows, 'kdprd')),
  )
  const hasData = computed(() => series.value.some((s) => s.values.some((v) => v)))
  const scope = computed(() => {
    if (isAo.value) return st.ao === 'all' ? 'semua AO' : aos.value.find((a) => a.id === st.ao)?.nama ?? ''
    return st.cabang === 'all' ? 'semua cabang' : o.kantors().find((k) => k.id === st.cabang)?.nama ?? ''
  })
  const unit = computed(() => (isAo.value ? 'per AO' : 'per produk'))
  const selTotal = computed(() => series.value.reduce((t, s) => t + (s.values[upto.value - 1] ?? 0), 0))
  /** % per bulan = kolom bln ÷ kolom `osKey` (mis. NPF ÷ OS). */
  const pctOf = (osKey: string): (number | null)[] => BLN.map((_, i) => {
    const m = String(i + 1).padStart(2, '0')
    const os = sumOf(filtered.value, `${osKey}${m}`)
    return os ? (sumOf(filtered.value, `bln${m}`) / os) * 100 : null
  })
  const table = computed(() =>
    isAo.value ? filtered.value : st.cabang === 'all' ? mergeBy(st.rows, 'kdprd', 'nmprd') : filtered.value,
  )
  const cols = computed<PbyCol[]>(() => [
    isAo.value ? { key: 'nmao', label: 'AO', sub: 'kdaoh' } : { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
    ...BLN.slice(0, upto.value).map((b, i) => ({ key: b, label: shortMonth(String(i + 1)), fmt: 'rp' as const })),
  ])

  return { st, months, year, upto, isAo, load, aos, series, hasData, scope, unit, selTotal, pctOf, table, cols }
}
