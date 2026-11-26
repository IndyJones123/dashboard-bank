<script setup lang="ts">
import { computed, onMounted, reactive, ref, toRef, watch } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import RpValue from './RpValue.vue'
import {
  KOL, RISK_COLORS, type Row, dateLabel, intText, lastMonth, monthLabel, npfOf, num, pctText, sumOf, sysDate, toPeriode,
} from '../pby-helpers'
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'
import PbyTable, { type PbyCol } from './PbyTable.vue'
import PbyList from './PbyList.vue'
import MoreDetails from './MoreDetails.vue'
import PbyStack, { type StackSeg } from './PbyStack.vue'
import PbyMonthBars from './PbyMonthBars.vue'
import PbyAoList, { type AoDetail } from './PbyAoList.vue'
import PbyDueList from './PbyDueList.vue'
import PbyTargetAo from './PbyTargetAo.vue'
import { BLN, colorsBy, toSeries, useTrend, type View } from '../pby-trend'

/* ==========================================================================
   PEMBIAYAAN · LIST SALDO
   Sumber (be/QueryData/pembiayaan, dieksekusi apa adanya lewat BE):
     OS berjalan / OS bulan : 004 OS Berjalan.sql / Pembiayaan OS Bulan.sql
     Realisasi              : 001 Realisasi Berjalan.sql / 002 Realisasi Perbulan.sql
     Kolektibilitas & NPF   : Pembiayaan NPF berjalan.sql / NPF Bulan.sql
   ========================================================================== */

const w = useWidgets('pembiayaan-saldo')

/* ---------- Tab atas: satu seksi tampil per waktu ---------- */
const SEC_TABS = [
  { id: 'os-bulanan', label: 'Outstanding' },
  { id: 'realisasi', label: 'Realisasi Pembiayaan' },
  { id: 'kolektibilitas', label: 'Kolektibilitas & NPF' },
  { id: 'jatuh-tempo', label: 'Pembiayaan Jatuh Tempo' },
  { id: 'target-ao', label: 'Target AO' },
] as const
type SecTab = (typeof SEC_TABS)[number]['id']
const secTabs = computed(() => SEC_TABS.filter((t) => w.show(t.id)))
const secTab = ref<SecTab>('os-bulanan')
watch(secTabs, (list) => {
  if (list.length && !list.some((t) => t.id === secTab.value)) secTab.value = list[0].id
})
function secTabKey(e: KeyboardEvent): void {
  const ids = secTabs.value.map((t) => t.id)
  const i = ids.indexOf(secTab.value)
  const next = e.key === 'ArrowRight' ? (i + 1) % ids.length
    : e.key === 'ArrowLeft' ? (i + ids.length - 1) % ids.length : -1
  if (next >= 0) { e.preventDefault(); secTab.value = ids[next] }
}

const subLabel = (key: string) => (r: Row): string => `Subtotal ${String(r[key] ?? '')}`

/** Tanggal sistem DB ('YYYY-MM-DD'); sebelum datang pakai tanggal lokal. */
const tgl = ref<string | null>(null)
const today = (): string => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
const sysIso = computed(() => tgl.value ?? today())
const heroDate = computed(() => dateLabel(sysIso.value))

/** Gabung baris semua kantor per produk (tabel rincian "Semua cabang"). */
function mergeByProduct(rows: Row[], nameKey: string): Row[] {
  const by = new Map<string, Row>()
  for (const r of rows) {
    const k = String(r.kdprd)
    const cur = by.get(k)
    if (!cur) by.set(k, { kdprd: r.kdprd, [nameKey]: r[nameKey], ...Object.fromEntries(BLN.map((b) => [b, num(r[b])])) })
    else for (const b of BLN) cur[b] = num(cur[b]) + num(r[b])
  }
  return [...by.values()]
}
const monthCols = (nameKey: string, upto = 12): PbyCol[] => [
  { key: nameKey, label: 'Produk', sub: 'kdprd' },
  ...BLN.slice(0, upto).map((b, i) => ({ key: b, label: shortMonth(String(i + 1)), fmt: 'rp' as const })),
]
/** Daftar kantor unik dari baris (kdloc -> nama). */
function kantorList(rows: Row[], nameKey: string): { kdloc: string; nama: string }[] {
  const m = new Map<string, string>()
  for (const r of rows) m.set(String(r.kdloc), String(r[nameKey] ?? `Kantor ${r.kdloc}`))
  return [...m.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([kdloc, nama]) => ({ kdloc, nama }))
}

/** Rupiah ringkas utk sel kecil: M = miliar, Jt = juta. */
function rpShort(v: number): string {
  const a = Math.abs(v)
  if (a >= 1e9) return `Rp ${(v / 1e9).toLocaleString('id-ID', { maximumFractionDigits: 2 })} M`
  if (a >= 1e6) return `Rp ${(v / 1e6).toLocaleString('id-ID', { maximumFractionDigits: 1 })} Jt`
  return formatRupiah(Math.round(v))
}

/* ==========================================================================
   OUTSTANDING
   ========================================================================== */
const osb = reactive({ loading: true, error: '', rows: [] as Row[] })
async function loadOsBerjalan(): Promise<void> {
  try {
    const { data } = await api.get<{ lokasi?: Row[] }>('/api/pembiayaan/os-berjalan', { timeout: 60000 })
    osb.rows = data.lokasi ?? []
  } catch (e) {
    osb.rows = []
    osb.error = apiErrText(e, 'Gagal memuat OS berjalan. Pastikan BE jalan.')
  } finally {
    osb.loading = false
  }
}
const osbVal = (v: number): number | null => (osb.rows.length ? Math.round(v) : null)
const osbMargin = computed(() => sumOf(osb.rows, 'osmgnc'))
const osbCols: PbyCol[] = [
  { key: 'nmkantor', label: 'Kantor', sub: 'kdloc' },
  { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
  { key: 'osmdlc', label: 'OS Pokok', fmt: 'rp' },
  { key: 'osmgnc', label: 'Margin', fmt: 'rp' },
]
const osbHeadChoices = [
  { key: 'osmdlc', label: 'OS Pokok' },
  { key: 'osmgnc', label: 'Margin' },
]

/* OS akhir bulan per produk (grafik pertumbuhan) */
const os = reactive({ loading: true, error: '', rows: [] as Row[] })
const osTahun = ref(String(new Date().getFullYear()))
const osYears = computed(() => {
  const top = Math.max(new Date().getFullYear(), Number(tgl.value?.slice(0, 4) ?? 0))
  return Array.from({ length: 8 }, (_, i) => String(top - i))
})
const osCabang = ref('all')
async function loadOs(first = false): Promise<void> {
  os.loading = true
  os.error = ''
  try {
    for (;;) {
      const { data } = await api.get<{ lokasi?: Row[] }>('/api/pembiayaan/os', { params: { tahun: osTahun.value }, timeout: 60000 })
      os.rows = data.lokasi ?? []
      const empty = !os.rows.some((r) => BLN.some((b) => num(r[b]) !== 0))
      // Muat pertama: DB bisa belum punya data thn berjalan -> mundur s.d. ketemu
      if (!first || !empty || osTahun.value === osYears.value[osYears.value.length - 1]) break
      osTahun.value = String(Number(osTahun.value) - 1)
    }
  } catch (e) {
    os.rows = []
    os.error = apiErrText(e, 'Gagal memuat OS per bulan. Pastikan BE jalan.')
  } finally {
    os.loading = false
  }
}
const osKantors = computed(() => kantorList(os.rows, 'nmcabang'))
watch(osKantors, (list) => {
  if (osCabang.value !== 'all' && !list.some((k) => k.kdloc === osCabang.value)) osCabang.value = 'all'
})
const osRows = computed(() => (osCabang.value === 'all' ? os.rows : os.rows.filter((r) => String(r.kdloc) === osCabang.value)))
const osSeries = computed(() => toSeries(osRows.value, 'kdprd', 'ket', colorsBy(os.rows, 'kdprd')))
const osHasData = computed(() => osSeries.value.some((s) => s.values.some((v) => v)))
const osLokasi = computed(() => (osCabang.value === 'all' ? 'semua cabang' : osKantors.value.find((k) => k.kdloc === osCabang.value)?.nama ?? ''))
const osTable = computed(() => (osCabang.value === 'all' ? mergeByProduct(os.rows, 'ket') : osRows.value))
const osDetOpen = ref(false)

/* ==========================================================================
   REALISASI: atas = bulan berjalan, bawah = pertumbuhan per bulan per produk
   ========================================================================== */
const real = reactive({ loading: true, error: '', rows: [] as Row[], ao: [] as Row[], view: 'lokasi' as View })
async function loadReal(): Promise<void> {
  real.loading = true
  real.error = ''
  try {
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[] }>('/api/pembiayaan/realisasi', { timeout: 60000 })
    real.rows = data.lokasi ?? []
    real.ao = data.ao ?? []
  } catch (e) {
    real.rows = []
    real.ao = []
    real.error = apiErrText(e, 'Gagal memuat realisasi pembiayaan. Pastikan BE jalan.')
  } finally {
    real.loading = false
  }
}
const realNoa = computed(() => sumOf(real.rows, 'qty_noa') + sumOf(real.rows, 'qty'))
const realPlf = computed(() => sumOf(real.rows, 'plf_noa') + sumOf(real.rows, 'plf'))
/** Kartu per kantor / per AO: angka utama = total plafon (baru + lama). */
const realCards = computed<Row[]>(() =>
  (real.view === 'ao' ? real.ao : real.rows)
    .map((r) => ({ ...r, total: num(r.plf_noa) + num(r.plf), noa: num(r.qty_noa) + num(r.qty) })),
)
const realCols = computed<PbyCol[]>(() => [
  ...(real.view === 'ao'
    ? [{ key: 'nmao', label: 'AO', sub: 'kdaoh' }]
    : [{ key: 'nmkantor', label: 'Kantor', sub: 'kdloc' }, { key: 'nmprd', label: 'Produk', sub: 'kdprd' }]),
  { key: 'total', label: 'Plafon', fmt: 'rp' },
  { key: 'noa', label: 'NOA', fmt: 'int' },
  { key: 'plf_noa', label: 'Plafon nasabah baru', fmt: 'rp' },
  { key: 'plf', label: 'Plafon nasabah lama', fmt: 'rp' },
])
const realStats = computed(() => [
  { label: 'Total plafon', value: realPlf.value, note: `${intText(realNoa.value)} NOA` },
  { label: 'Nasabah baru', value: sumOf(real.rows, 'plf_noa'), note: `${intText(sumOf(real.rows, 'qty_noa'))} NOA` },
  { label: 'Nasabah lama', value: sumOf(real.rows, 'plf'), note: `${intText(sumOf(real.rows, 'qty'))} NOA` },
])

/* AO: warna & rincian kartu */
const realAoColors = computed(() => colorsBy(real.ao, 'kdaoh'))
const realAoValue = (r: Row): number => num(r.plf_noa) + num(r.plf)
const realAoDetails: AoDetail[] = [
  { label: 'NOA', text: (r) => intText(num(r.qty_noa) + num(r.qty)) },
  { label: 'Baru', text: (r) => rpShort(num(r.plf_noa)) },
  { label: 'Lama', text: (r) => rpShort(num(r.plf)) },
]
const realKantors = computed(() => kantorList(real.rows, 'nmkantor'))

/* Grafik pertumbuhan: Jan s.d. bulan terpilih; per produk (Cabang) atau per AO */
const rt = reactive(useTrend({
  url: '/api/pembiayaan/realisasi-tahun',
  view: toRef(real, 'view'),
  end: () => sysIso.value.slice(0, 7),
  mark: 'berjalan',
  kantors: () => realKantors.value.map((k) => ({ id: k.kdloc, nama: k.nama })),
  aoColors: () => realAoColors.value,
  errText: 'Gagal memuat realisasi per bulan. Pastikan BE jalan.',
}))

/* ==========================================================================
   KOLEKTIBILITAS & NPF: atas = posisi berjalan, bawah = NPF akhir bulan per produk
   ========================================================================== */
const npf = reactive({ loading: true, error: '', lokasi: [] as Row[], ao: [] as Row[], view: 'lokasi' as View })
async function loadNpf(): Promise<void> {
  npf.loading = true
  npf.error = ''
  try {
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[] }>('/api/pembiayaan/npf', { timeout: 60000 })
    npf.lokasi = data.lokasi ?? []
    npf.ao = data.ao ?? []
  } catch (e) {
    npf.lokasi = []
    npf.ao = []
    npf.error = apiErrText(e, 'Gagal memuat kolektibilitas & NPF. Pastikan BE jalan.')
  } finally {
    npf.loading = false
  }
}
const totalOs = computed(() => sumOf(npf.lokasi, 'os'))
const totalNpf = computed(() => npfOf(npf.lokasi))
const npfNominal = computed(() => sumOf(npf.lokasi, 'coll3') + sumOf(npf.lokasi, 'coll4') + sumOf(npf.lokasi, 'coll5'))
const pctOfOs = (v: number): string => (totalOs.value ? pctText((v / totalOs.value) * 100) : '–')
const npfStats = computed(() => [
  { label: 'Outstanding', value: totalOs.value, note: `${kantorList(npf.lokasi, 'nmcabang').length} kantor`, bad: false },
  { label: 'NPF (Kol 3 + 4 + 5)', value: npfNominal.value, note: `NPF ${pctText(totalNpf.value)}`, bad: (totalNpf.value ?? 0) > 5 },
  { label: 'Kol 2 Dalam Perhatian Khusus', value: sumOf(npf.lokasi, 'coll2'), note: `${pctOfOs(sumOf(npf.lokasi, 'coll2'))} dari outstanding`, bad: false },
])
/** Kartu per kantor / per AO: angka utama = outstanding, toggle ke NPF nominal. */
const npfCards = computed<Row[]>(() =>
  (npf.view === 'ao' ? npf.ao : npf.lokasi).map((r) => ({ ...r, npfrp: num(r.coll3) + num(r.coll4) + num(r.coll5) })),
)
const npfCols = computed<PbyCol[]>(() => [
  ...(npf.view === 'ao'
    ? [{ key: 'nmao', label: 'AO Handle', sub: 'kdaoh' }]
    : [{ key: 'nmcabang', label: 'Kantor', sub: 'kdloc' }, { key: 'ket', label: 'Produk', sub: 'kdprd' }]),
  { key: 'os', label: 'Outstanding', fmt: 'rp' },
  { key: 'npfrp', label: 'NPF', fmt: 'rp' },
  { key: 'npf', label: 'NPF %', fmt: 'pct', sum: false },
])
const npfOverride = (rows: Row[]): Row => ({ npf: npfOf(rows) })
const npfHeadChoices = [
  { key: 'os', label: 'Outstanding', pct: false as const },
  { key: 'npfrp', label: 'NPF', pct: (r: Row) => npfOf([r]) },
]
/** Baris NPF % per kantor di bawah Jumlah NPF (merah bila > 5%). */
const npfSumExtras = [
  { label: '', value: (rows: Row[]) => pctText(npfOf(rows)), bad: (rows: Row[]) => (npfOf(rows) ?? 0) > 5 },
]
const kolSegs = computed<StackSeg[]>(() =>
  KOL.map((k, i) => ({ key: k.key, label: `${k.label} ${k.name}`, value: sumOf(npf.lokasi, k.key), color: RISK_COLORS[i] })),
)

/* AO: warna & rincian kartu */
const npfAoColors = computed(() => colorsBy(npf.ao, 'kdaoh'))
const npfAoValue = (r: Row): number => num(r.os)
const npfRp = (r: Row): number => num(r.coll3) + num(r.coll4) + num(r.coll5)
const npfAoDetails: AoDetail[] = [
  { label: 'NPF', text: (r) => rpShort(npfRp(r)) },
  { label: 'NPF %', text: (r) => pctText(npfOf([r])), bad: (r) => (npfOf([r]) ?? 0) > 5 },
  { label: 'Kol 2 DPK', text: (r) => rpShort(num(r.coll2)) },
]
const npfKantors = computed(() => kantorList(npf.lokasi, 'nmcabang'))

/* Grafik NPF akhir bulan: Jan s.d. bulan terpilih (default bulan lalu = EOM terakhir) */
const nt = reactive(useTrend({
  url: '/api/pembiayaan/npf-tahun',
  view: toRef(npf, 'view'),
  end: () => lastMonth(sysIso.value),
  mark: 'akhir bulan terakhir',
  kantors: () => npfKantors.value.map((k) => ({ id: k.kdloc, nama: k.nama })),
  aoColors: () => npfAoColors.value,
  errText: 'Gagal memuat NPF per bulan. Pastikan BE jalan.',
}))
const ntPct = computed(() => nt.pctOf('os'))
const ntTops = computed(() => ntPct.value.map((v) => (v == null ? null : pctText(v))))

/* ==========================================================================
   PEMBIAYAAN JATUH TEMPO (Pembiayaan JatuhTempo.sql): kontrak aktif yang
   tanggal jatuh temponya (tglexp) <= tanggal sistem
   ========================================================================== */
const jt = reactive({
  loading: true, error: '', lokasi: [] as Row[], ao: [] as Row[], nasabah: [] as Row[], view: 'lokasi' as View,
})
async function loadJt(): Promise<void> {
  jt.loading = true
  jt.error = ''
  try {
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[]; nasabah?: Row[] }>('/api/pembiayaan/jatuh-tempo', { timeout: 60000 })
    jt.lokasi = data.lokasi ?? []
    jt.ao = data.ao ?? []
    jt.nasabah = data.nasabah ?? []
  } catch (e) {
    jt.lokasi = []
    jt.ao = []
    jt.nasabah = []
    jt.error = apiErrText(e, 'Gagal memuat pembiayaan jatuh tempo. Pastikan BE jalan.')
  } finally {
    jt.loading = false
  }
}
const jtStats = computed(() => [
  { label: 'OS Pokok Jatuh Tempo', value: sumOf(jt.lokasi, 'osmdlc'), note: `${intText(sumOf(jt.lokasi, 'qty'))} kontrak` },
  { label: 'Margin', value: sumOf(jt.lokasi, 'osmgnc'), note: 'Sisa margin kontrak jatuh tempo' },
  { label: 'Pokok + margin', value: sumOf(jt.lokasi, 'osmdlc') + sumOf(jt.lokasi, 'osmgnc'), note: `${kantorList(jt.lokasi, 'nmcabang').length} kantor` },
])
const jtCols: PbyCol[] = [
  { key: 'nmcabang', label: 'Kantor', sub: 'kdloc' },
  { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
  { key: 'osmdlc', label: 'OS Pokok', fmt: 'rp' },
  { key: 'osmgnc', label: 'Margin', fmt: 'rp' },
  { key: 'qty', label: 'Kontrak', fmt: 'int' },
]
const jtHeadChoices = [
  { key: 'osmdlc', label: 'OS Pokok' },
  { key: 'osmgnc', label: 'Margin' },
]
const jtSumExtras = [{ label: 'Jumlah Kontrak', value: (rows: Row[]) => intText(sumOf(rows, 'qty')) }]
const jtAoColors = computed(() => colorsBy(jt.ao, 'kdaoh'))
const jtAoValue = (r: Row): number => num(r.osmdlc)
const jtAoDetails: AoDetail[] = [
  { label: 'Kontrak', text: (r) => intText(num(r.qty)) },
  { label: 'Margin', text: (r) => rpShort(num(r.osmgnc)) },
]
/* Daftar nasabah: filter kantor + cari, urut paling lama lewat jatuh tempo */
const jtQ = ref('')
const jtKantor = ref('')
const jtKantors = computed(() => [...new Set(jt.nasabah.map((r) => String(r.kdloc)))].sort())
const jtNama = computed(() => new Map(kantorList(jt.lokasi, 'nmcabang').map((k) => [k.kdloc, k.nama])))
const jtRows = computed(() => {
  const s = jtQ.value.trim().toLowerCase()
  return jt.nasabah
    .filter((r) => !jtKantor.value || String(r.kdloc) === jtKantor.value)
    .filter((r) => !s || ['nama', 'nokontrak'].some((k) => String(r[k] ?? '').toLowerCase().includes(s)))
    .sort((a, b) => num(b.tgkhari) - num(a.tgkhari))
})
/** Nama produk (kdprd -> nmprd) dari seksi lokasi & produk utk kartu nasabah. */
const jtProduk = computed(() => new Map(jt.lokasi.map((r) => [String(r.kdprd), String(r.nmprd ?? '')])))

/* ==========================================================================
   TARGET AO (003 Pembiayaan Target AO.sql): target vs realisasi per AO,
   per periode (bulan). Default bulan sistem.
   ========================================================================== */
const tao = reactive({ loading: true, error: '', rows: [] as Row[], bulan: sysIso.value.slice(0, 7) })
async function loadTao(): Promise<void> {
  tao.loading = true
  tao.error = ''
  try {
    const { data } = await api.get<{ rows?: Row[] }>('/api/pembiayaan/target-ao', {
      params: { periode: toPeriode(tao.bulan) }, timeout: 60000,
    })
    tao.rows = data.rows ?? []
  } catch (e) {
    tao.rows = []
    tao.error = apiErrText(e, 'Gagal memuat target AO. Pastikan BE jalan.')
  } finally {
    tao.loading = false
  }
}
/** Pilihan bulan: bulan sistem mundur 12 bulan. */
const taoMonths = computed(() => {
  const [y, m] = sysIso.value.slice(0, 7).split('-').map(Number)
  return Array.from({ length: 12 }, (_, i) => {
    const d = new Date(y, m - 1 - i, 1)
    const v = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    return { v, label: monthLabel(v) }
  })
})
const capai = (real: number, target: number): string => (target ? pctText((real / target) * 100) : '–')
const taoStats = computed(() => {
  const loan = sumOf(tao.rows, 'loan')
  const rloan = sumOf(tao.rows, 'rloan')
  const dep = sumOf(tao.rows, 'dep')
  const rdep = sumOf(tao.rows, 'rdep')
  return [
    { label: 'Realisasi Pembiayaan', value: rloan, note: `Capaian ${capai(rloan, loan)} dari target ${rpShort(loan)}` },
    { label: 'Realisasi Deposito', value: rdep, note: `Capaian ${capai(rdep, dep)} dari target ${rpShort(dep)}` },
    { label: 'Target Tabungan', value: sumOf(tao.rows, 'tab'), note: `${tao.rows.length} AO · realisasi belum tersedia` },
  ]
})
/** Nama kantor (kdloc -> nama) utk kartu AO, dari data NPF per lokasi. */
const taoKantor = computed(() => new Map(npfKantors.value.map((k) => [k.kdloc, k.nama])))

/* Grafik 1 tahun: pembiayaan & deposito (garis) vs targetnya (putus-putus),
   Jan s.d. bulan sistem (tahun berjalan) atau Jan–Des (tahun lalu). */
interface TaoYearAo { kdao: string; nmao: string; loan: number[]; rloan: number[]; dep: number[]; rdep: number[] }
const taoY = reactive({ tahun: sysIso.value.slice(0, 4), ao: 'all', loading: true, error: '', rows: [] as TaoYearAo[] })
const taoYears = computed(() => {
  const top = Number(sysIso.value.slice(0, 4))
  return Array.from({ length: 5 }, (_, i) => String(top - i))
})
const taoUpto = computed(() => (taoY.tahun === sysIso.value.slice(0, 4) ? Number(sysIso.value.slice(5, 7)) : 12))
async function loadTaoYear(): Promise<void> {
  taoY.loading = true
  taoY.error = ''
  try {
    const { data } = await api.get<{ ao?: TaoYearAo[] }>('/api/pembiayaan/target-ao-tahun', {
      params: { tahun: taoY.tahun, sampai: taoUpto.value }, timeout: 90000,
    })
    taoY.rows = data.ao ?? []
    if (taoY.ao !== 'all' && !taoY.rows.some((r) => String(r.kdao) === taoY.ao)) taoY.ao = 'all'
  } catch (e) {
    taoY.rows = []
    taoY.error = apiErrText(e, 'Gagal memuat target AO per bulan. Pastikan BE jalan.')
  } finally {
    taoY.loading = false
  }
}
const taoYLabels = computed(() => Array.from({ length: taoUpto.value }, (_, i) => shortMonth(String(i + 1))))
const taoYSeries = computed<LineSerie[]>(() => {
  const src = taoY.ao === 'all' ? taoY.rows : taoY.rows.filter((r) => String(r.kdao) === taoY.ao)
  const sum = (k: 'loan' | 'rloan' | 'dep' | 'rdep'): number[] =>
    Array.from({ length: taoUpto.value }, (_, i) => src.reduce((t, r) => t + (Number(r[k]?.[i]) || 0), 0))
  // Warna terang & kontras satu sama lain: oranye (pembiayaan) vs biru (deposito)
  const LOAN = '#f2620f'
  const DEP = '#1f6bff'
  return [
    { key: 'rloan', label: 'Pembiayaan', color: LOAN, values: sum('rloan') },
    { key: 'loan', label: 'Target pembiayaan', color: LOAN, dash: '6 4', values: sum('loan') },
    { key: 'rdep', label: 'Deposito', color: DEP, values: sum('rdep') },
    { key: 'dep', label: 'Target deposito', color: DEP, dash: '6 4', values: sum('dep') },
  ]
})
const taoYHasData = computed(() => taoYSeries.value.some((s) => s.values.some((v) => v)))
const taoYScope = computed(() =>
  taoY.ao === 'all' ? 'semua AO' : taoY.rows.find((r) => String(r.kdao) === taoY.ao)?.nmao ?? '',
)

onMounted(async () => {
  void loadJt()
  void loadNpf()
  void loadReal()
  void loadOsBerjalan()
  tgl.value = await sysDate()
  if (tgl.value) {
    nt.st.bulan = lastMonth(tgl.value)
    osTahun.value = tgl.value.slice(0, 4)
    rt.st.bulan = tgl.value.slice(0, 7)
    tao.bulan = tgl.value.slice(0, 7)
    taoY.tahun = tgl.value.slice(0, 4)
  }
  void loadTao()
  void loadTaoYear()
  void loadOs(true)
  void rt.load()
  void nt.load()
})
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>List Saldo Pembiayaan</h1>
        <p>Outstanding, realisasi, dan kolektibilitas pembiayaan. Tanggal sistem: <strong>{{ heroDate }}</strong>.</p>
      </div>
    </div>

    <WidgetNotice :w="w" />
    <div class="wgrid">
      <section v-if="w.show('angka-utama')" class="w lead-part hero" :style="w.style('angka-utama')">
        <p class="lead-label">Outstanding Pembiayaan</p>
        <p class="lead-value num"><RpValue :value="npf.loading ? null : Math.round(totalOs)" /></p>
        <p class="lead-note">Posisi berjalan, semua kantor</p>
      </section>
      <section v-if="w.show('ringkasan')" class="w lead-part" :style="w.style('ringkasan')">
        <dl class="ledger">
          <div>
            <dt>Margin <small>Margin</small></dt>
            <dd class="num"><RpValue :value="osbVal(osbMargin)" /></dd>
          </div>
          <div>
            <dt>NPF <small>Kol 3 + 4 + 5 = <template v-if="npf.loading">–</template><RpValue v-else :value="Math.round(npfNominal)" /></small></dt>
            <dd class="num" :class="totalNpf != null && totalNpf > 5 ? 'g-down' : ''">{{ npf.loading ? '–' : pctText(totalNpf) }}</dd>
          </div>
          <div>
            <dt>
              Realisasi
              <small class="rl-split">
                <span class="rl-line">
                  {{ real.loading ? '–' : intText(sumOf(real.rows, 'qty_noa')) }} Nasabah Baru
                  <b class="num"><template v-if="real.loading">–</template><RpValue v-else :value="Math.round(sumOf(real.rows, 'plf_noa'))" /></b>
                </span>
                <span class="rl-line">
                  {{ real.loading ? '–' : intText(sumOf(real.rows, 'qty')) }} Nasabah Lama
                  <b class="num"><template v-if="real.loading">–</template><RpValue v-else :value="Math.round(sumOf(real.rows, 'plf'))" /></b>
                </span>
              </small>
            </dt>
            <dd class="num"><RpValue :value="real.loading ? null : Math.round(realPlf)" /></dd>
          </div>
        </dl>
      </section>

      <nav
        v-if="secTabs.length > 1" class="w ptabs" role="tablist" aria-label="Bagian List Saldo"
        :style="{ order: 2 }" @keydown="secTabKey"
      >
        <button
          v-for="t in secTabs" :id="`tab-${t.id}`" :key="t.id" type="button" role="tab"
          :aria-selected="secTab === t.id" :aria-controls="`pnl-${t.id}`"
          :class="{ on: secTab === t.id }" @click="secTab = t.id"
        >{{ t.label }}</button>
      </nav>

      <!-- ============ OUTSTANDING ============ -->
      <section
        v-if="secTab === 'os-bulanan' && w.show('os-bulanan')" id="pnl-os-bulanan" role="tabpanel"
        aria-labelledby="tab-os-bulanan" class="w panel" :style="w.style('os-bulanan')"
      >
        <div class="pby-head">
          <div>
            <h2>Outstanding Berjalan</h2>
            <p class="sub">Posisi {{ heroDate }}, per kantor dan produk.</p>
          </div>
        </div>
        <p v-if="osb.loading" class="muted">Memuat outstanding berjalan…</p>
        <p v-else-if="osb.error" class="alert">{{ osb.error }}</p>
        <PbyList
          v-else :cols="osbCols" :rows="osb.rows" :head-choices="osbHeadChoices"
          subtotal-by="kdloc" :subtotal-label="subLabel('nmkantor')"
          empty="Belum ada data outstanding berjalan."
        />

        <div class="sub-sec">
          <div class="pby-head">
            <div>
              <h2>Pertumbuhan Outstanding {{ osTahun }}</h2>
              <p class="sub">Outstanding pokok akhir bulan per produk, {{ osLokasi }}.</p>
            </div>
            <div class="pby-ctrl filters">
              <label>
                Cabang
                <select v-model="osCabang" :disabled="!osKantors.length">
                  <option value="all">Semua cabang</option>
                  <option v-for="k in osKantors" :key="k.kdloc" :value="k.kdloc">{{ k.nama }}</option>
                </select>
              </label>
              <label>
                Tahun
                <select v-model="osTahun" @change="loadOs()">
                  <option v-for="y in osYears" :key="y" :value="y">{{ y }}</option>
                </select>
              </label>
            </div>
          </div>
          <p v-if="os.loading" class="muted">Memuat outstanding bulanan…</p>
          <p v-else-if="os.error" class="alert">{{ os.error }}</p>
          <p v-else-if="!osHasData" class="muted">Belum ada data akhir bulan untuk {{ osTahun }}.</p>
          <template v-else>
            <PbyMonthBars :series="osSeries" :label="`Grafik outstanding per produk ${osLokasi} ${osTahun}`" />
            <MoreDetails id="det-os-bulanan" :open="osDetOpen" @toggle="osDetOpen = !osDetOpen">
              <PbyTable :cols="monthCols('ket')" :rows="osTable" empty="Belum ada data produk." />
            </MoreDetails>
          </template>
        </div>
      </section>

      <!-- ============ REALISASI ============ -->
      <section
        v-if="secTab === 'realisasi' && w.show('realisasi')" id="pnl-realisasi" role="tabpanel"
        aria-labelledby="tab-realisasi" class="w panel" :style="w.style('realisasi')"
      >
        <div class="pby-head">
          <div>
            <h2>Realisasi Bulan Berjalan</h2>
            <p class="sub">Pencairan / Dropping {{ monthLabel(sysIso.slice(0, 7)) }}.</p>
          </div>
          <div class="pby-ctrl">
            <div class="segmented" role="group" aria-label="Kelompokkan realisasi">
              <button type="button" :class="{ on: real.view === 'lokasi' }" :aria-pressed="real.view === 'lokasi'" @click="real.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: real.view === 'ao' }" :aria-pressed="real.view === 'ao'" @click="real.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="real.loading" class="muted">Memuat realisasi…</p>
        <p v-else-if="real.error" class="alert">{{ real.error }}</p>
        <template v-else>
          <dl class="stat-row">
            <div v-for="s in realStats" :key="s.label">
              <dt>{{ s.label }}</dt>
              <dd class="num"><RpValue :value="Math.round(s.value)" /></dd>
              <dd class="stat-note">{{ s.note }}</dd>
            </div>
          </dl>
          <PbyAoList
            v-if="real.view === 'ao'" :rows="real.ao" :value="realAoValue" value-label="Plafon"
            :details="realAoDetails" :colors="realAoColors" empty="Belum ada pencairan AO bulan ini."
          />
          <PbyList
            v-else :cols="realCols" :rows="realCards"
            subtotal-by="kdloc" :subtotal-label="subLabel('nmkantor')"
            empty="Belum ada pencairan bulan ini."
          />
        </template>

        <div class="sub-sec">
          <div class="pby-head">
            <div>
              <h2>Pertumbuhan Realisasi {{ rt.year }}</h2>
              <p class="sub">
                Plafon pencairan per bulan {{ rt.unit }}, {{ rt.scope }}.
                <template v-if="!rt.st.loading && rt.hasData">{{ monthLabel(rt.st.bulan) }}: <strong class="num"><RpValue :value="Math.round(rt.selTotal)" /></strong></template>
              </p>
            </div>
            <div class="pby-ctrl filters">
              <label>
                Bulan
                <select v-model="rt.st.bulan" @change="rt.load()">
                  <option v-for="m in rt.months" :key="m.v" :value="m.v">{{ m.label }}</option>
                </select>
              </label>
              <label v-if="rt.isAo">
                AO
                <select v-model="rt.st.ao" :disabled="!rt.aos.length">
                  <option value="all">Semua AO</option>
                  <option v-for="a in rt.aos" :key="a.id" :value="a.id">{{ a.nama }}</option>
                </select>
              </label>
              <label v-else>
                Cabang
                <select v-model="rt.st.cabang" :disabled="!realKantors.length">
                  <option value="all">Semua cabang</option>
                  <option v-for="k in realKantors" :key="k.kdloc" :value="k.kdloc">{{ k.nama }}</option>
                </select>
              </label>
            </div>
          </div>
          <p v-if="rt.st.loading" class="muted">Memuat data per bulan…</p>
          <p v-else-if="rt.st.error" class="alert">{{ rt.st.error }}</p>
          <p v-else-if="!rt.hasData" class="muted">Belum ada data pada {{ rt.year }} untuk {{ rt.scope }}.</p>
          <template v-else>
            <PbyMonthBars
              :series="rt.series" :months="rt.upto" :highlight="rt.upto"
              :label="`Grafik realisasi ${rt.unit} ${rt.scope} Januari sampai ${monthLabel(rt.st.bulan)}`"
            />
            <MoreDetails id="det-rt" :open="rt.st.det" @toggle="rt.st.det = !rt.st.det">
              <PbyTable :cols="rt.cols" :rows="rt.table" empty="Belum ada data." />
            </MoreDetails>
          </template>
        </div>
      </section>

      <!-- ============ KOLEKTIBILITAS & NPF ============ -->
      <section
        v-if="secTab === 'kolektibilitas' && w.show('kolektibilitas')" id="pnl-kolektibilitas" role="tabpanel"
        aria-labelledby="tab-kolektibilitas" class="w panel" :style="w.style('kolektibilitas')"
      >
        <div class="pby-head">
          <div>
            <h2>Kolektibilitas Berjalan</h2>
            <p class="sub">Posisi {{ heroDate }}. Nilai = outstanding pokok; NPF = Kol 3 + 4 + 5.</p>
          </div>
          <div class="pby-ctrl">
            <div class="segmented" role="group" aria-label="Kelompokkan kolektibilitas">
              <button type="button" :class="{ on: npf.view === 'lokasi' }" :aria-pressed="npf.view === 'lokasi'" @click="npf.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: npf.view === 'ao' }" :aria-pressed="npf.view === 'ao'" @click="npf.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="npf.loading" class="muted">Memuat kolektibilitas…</p>
        <p v-else-if="npf.error" class="alert">{{ npf.error }}</p>
        <template v-else>
          <dl class="stat-row">
            <div v-for="s in npfStats" :key="s.label">
              <dt>{{ s.label }}</dt>
              <dd class="num"><RpValue :value="Math.round(s.value)" /></dd>
              <dd class="stat-note" :class="{ bad: s.bad }">{{ s.note }}</dd>
            </div>
          </dl>
          <PbyStack :segs="kolSegs" label="Komposisi outstanding per kolektibilitas" />
          <PbyAoList
            v-if="npf.view === 'ao'" :rows="npf.ao" :value="npfAoValue" value-label="Outstanding"
            :details="npfAoDetails" :colors="npfAoColors" :total-note="`NPF ${pctText(npfOf(npf.ao))}`"
            empty="Belum ada data kolektibilitas AO."
          />
          <PbyList
            v-else :cols="npfCols" :rows="npfCards" :head-choices="npfHeadChoices" :sum-extras="npfSumExtras" :total-override="npfOverride"
            subtotal-by="kdloc" :subtotal-label="subLabel('nmcabang')"
            empty="Belum ada data kolektibilitas."
          />
        </template>

        <div class="sub-sec">
          <div class="pby-head">
            <div>
              <h2>Pertumbuhan NPF {{ nt.year }}</h2>
              <p class="sub">
                NPF akhir bulan (Kol 3 + 4 + 5) {{ nt.unit }}, {{ nt.scope }}. Angka di atas batang = NPF %.
                <template v-if="!nt.st.loading && nt.hasData">{{ monthLabel(nt.st.bulan) }}: <strong class="num">{{ pctText(ntPct[nt.upto - 1] ?? null) }} · <RpValue :value="Math.round(nt.selTotal)" /></strong></template>
              </p>
            </div>
            <div class="pby-ctrl filters">
              <label>
                Bulan
                <select v-model="nt.st.bulan" @change="nt.load()">
                  <option v-for="m in nt.months" :key="m.v" :value="m.v">{{ m.label }}</option>
                </select>
              </label>
              <label v-if="nt.isAo">
                AO
                <select v-model="nt.st.ao" :disabled="!nt.aos.length">
                  <option value="all">Semua AO</option>
                  <option v-for="a in nt.aos" :key="a.id" :value="a.id">{{ a.nama }}</option>
                </select>
              </label>
              <label v-else>
                Cabang
                <select v-model="nt.st.cabang" :disabled="!npfKantors.length">
                  <option value="all">Semua cabang</option>
                  <option v-for="k in npfKantors" :key="k.kdloc" :value="k.kdloc">{{ k.nama }}</option>
                </select>
              </label>
            </div>
          </div>
          <p v-if="nt.st.loading" class="muted">Memuat data per bulan…</p>
          <p v-else-if="nt.st.error" class="alert">{{ nt.st.error }}</p>
          <p v-else-if="!nt.hasData" class="muted">Belum ada data pada {{ nt.year }} untuk {{ nt.scope }}.</p>
          <template v-else>
            <PbyMonthBars
              :series="nt.series" :months="nt.upto" :highlight="nt.upto" :tops="ntTops"
              :label="`Grafik NPF ${nt.unit} ${nt.scope} Januari sampai ${monthLabel(nt.st.bulan)}`"
            />
            <MoreDetails id="det-nt" :open="nt.st.det" @toggle="nt.st.det = !nt.st.det">
              <PbyTable :cols="nt.cols" :rows="nt.table" empty="Belum ada data." />
            </MoreDetails>
          </template>
        </div>
      </section>

      <!-- ============ PEMBIAYAAN JATUH TEMPO ============ -->
      <section
        v-if="secTab === 'jatuh-tempo' && w.show('jatuh-tempo')" id="pnl-jatuh-tempo" role="tabpanel"
        aria-labelledby="tab-jatuh-tempo" class="w panel" :style="w.style('jatuh-tempo')"
      >
        <div class="pby-head">
          <div>
            <h2>Pembiayaan Jatuh Tempo</h2>
            <p class="sub">Kontrak aktif yang jatuh temponya s.d. {{ heroDate }}.</p>
          </div>
          <div class="pby-ctrl">
            <div class="segmented" role="group" aria-label="Kelompokkan jatuh tempo">
              <button type="button" :class="{ on: jt.view === 'lokasi' }" :aria-pressed="jt.view === 'lokasi'" @click="jt.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: jt.view === 'ao' }" :aria-pressed="jt.view === 'ao'" @click="jt.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="jt.loading" class="muted">Memuat pembiayaan jatuh tempo…</p>
        <p v-else-if="jt.error" class="alert">{{ jt.error }}</p>
        <template v-else>
          <dl class="stat-row">
            <div v-for="s in jtStats" :key="s.label">
              <dt>{{ s.label }}</dt>
              <dd class="num"><RpValue :value="Math.round(s.value)" /></dd>
              <dd class="stat-note">{{ s.note }}</dd>
            </div>
          </dl>
          <PbyAoList
            v-if="jt.view === 'ao'" :rows="jt.ao" :value="jtAoValue" value-label="OS Pokok"
            :details="jtAoDetails" :colors="jtAoColors" empty="Tidak ada pembiayaan jatuh tempo per AO."
          />
          <PbyList
            v-else :cols="jtCols" :rows="jt.lokasi" :head-choices="jtHeadChoices" :sum-extras="jtSumExtras"
            subtotal-by="kdloc" :subtotal-label="subLabel('nmcabang')"
            empty="Tidak ada pembiayaan jatuh tempo."
          />
        </template>

        <div class="sub-sec">
          <div class="pby-head">
            <div>
              <h2>Daftar Nasabah Jatuh Tempo</h2>
              <p class="sub">Diurutkan dari yang paling lama lewat jatuh tempo.</p>
            </div>
            <div class="pby-ctrl filters">
              <label>
                Kantor
                <select v-model="jtKantor">
                  <option value="">Semua</option>
                  <option v-for="k in jtKantors" :key="k" :value="k">{{ jtNama.get(k) ?? k }}</option>
                </select>
              </label>
              <input v-model="jtQ" type="search" placeholder="Cari nama, kontrak" aria-label="Cari nasabah jatuh tempo" />
            </div>
          </div>
          <p v-if="jt.loading" class="muted">Memuat daftar nasabah…</p>
          <p v-else-if="jt.error" class="alert">{{ jt.error }}</p>
          <PbyDueList
            v-else :rows="jtRows" :kantor-nama="jtNama" :produk-nama="jtProduk" :per-page="12"
            :empty="jtQ || jtKantor ? 'Tidak ada nasabah yang cocok.' : 'Tidak ada nasabah jatuh tempo.'"
          />
        </div>
      </section>

      <!-- ============ TARGET AO ============ -->
      <section
        v-if="secTab === 'target-ao' && w.show('target-ao')" id="pnl-target-ao" role="tabpanel"
        aria-labelledby="tab-target-ao" class="w panel" :style="w.style('target-ao')"
      >
        <div class="pby-head">
          <div>
            <h2>Target AO</h2>
            <p class="sub">Target VS Realisasi per AO, {{ monthLabel(tao.bulan) }}. Capaian = realisasi ÷ target.</p>
          </div>
          <div class="pby-ctrl filters">
            <label>
              Bulan
              <select v-model="tao.bulan" @change="loadTao()">
                <option v-for="m in taoMonths" :key="m.v" :value="m.v">{{ m.label }}</option>
              </select>
            </label>
          </div>
        </div>
        <p v-if="tao.loading" class="muted">Memuat target AO…</p>
        <p v-else-if="tao.error" class="alert">{{ tao.error }}</p>
        <p v-else-if="!tao.rows.length" class="muted">Belum ada target AO untuk {{ monthLabel(tao.bulan) }}.</p>
        <template v-else>
          <dl class="stat-row">
            <div v-for="s in taoStats" :key="s.label">
              <dt>{{ s.label }}</dt>
              <dd class="num"><RpValue :value="Math.round(s.value)" /></dd>
              <dd class="stat-note">{{ s.note }}</dd>
            </div>
          </dl>
          <PbyTargetAo :rows="tao.rows" :kantor-nama="taoKantor" />
        </template>

        <div class="sub-sec">
          <div class="pby-head">
            <div>
              <h2>Target vs realisasi {{ taoY.tahun }}</h2>
              <p class="sub">Per bulan, {{ taoYScope }}. Garis = realisasi, putus-putus = target.</p>
            </div>
            <div class="pby-ctrl filters">
              <label>
                Tahun
                <select v-model="taoY.tahun" @change="loadTaoYear()">
                  <option v-for="y in taoYears" :key="y" :value="y">{{ y }}</option>
                </select>
              </label>
              <label>
                AO
                <select v-model="taoY.ao" :disabled="!taoY.rows.length">
                  <option value="all">Semua AO</option>
                  <option v-for="a in taoY.rows" :key="a.kdao" :value="String(a.kdao)">{{ a.nmao }}</option>
                </select>
              </label>
            </div>
          </div>
          <p v-if="taoY.loading" class="muted">Memuat data per bulan…</p>
          <p v-else-if="taoY.error" class="alert">{{ taoY.error }}</p>
          <p v-else-if="!taoYHasData" class="muted">Belum ada target AO pada {{ taoY.tahun }}.</p>
          <LineChart
            v-else :labels="taoYLabels" :series="taoYSeries"
            :aria-label="`Grafik target vs realisasi pembiayaan dan deposito ${taoYScope} ${taoY.tahun}`"
          />
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
/* Ringkasan Realisasi: rincian nasabah baru / lama di bawah judul (kiri),
   jumlahnya di kanan */
.rl-split { display: flex; flex-direction: column; gap: 0.1rem; margin-top: 0.1rem; }
.rl-line { display: flex; align-items: baseline; gap: 0.5rem; white-space: nowrap; }
.rl-line b { font-weight: 600; color: var(--ink-2, var(--ink)); }

/* Tab seksi (Outstanding | Realisasi | Kolektibilitas) */
.ptabs {
  display: flex; gap: 0.25rem;
  border-bottom: 1px solid var(--border-strong);
}
.ptabs button {
  min-height: 40px; padding: 0.45rem 1rem;
  border: none; background: none; cursor: pointer; font-family: inherit;
  font-size: var(--fs-sm); font-weight: 500; color: var(--muted);
  border-bottom: 2px solid transparent; margin-bottom: -1px;
}
.ptabs button:hover { color: var(--ink); }
.ptabs button.on { color: var(--primary); border-bottom-color: var(--primary); font-weight: 600; }
.ptabs button:focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }

/* Sub-bagian di bawah kartu (grafik pertumbuhan) */
.sub-sec { margin-top: 1.75rem; padding-top: 1.5rem; border-top: 1px solid var(--border-strong); }
.sub-sec .pby-head { margin-bottom: 1rem; flex-wrap: nowrap; }
/* Judul menyusut, dropdown tetap di kanan atas grafik */
.sub-sec .pby-head > div:first-child { flex: 1 1 auto; min-width: 0; }
.sub-sec .pby-ctrl { flex: none; flex-wrap: nowrap; }
@media (max-width: 860px) {
  .sub-sec .pby-head { flex-wrap: wrap; }
}
.sub .num { color: var(--ink); font-weight: 600; white-space: nowrap; }

/* Ringkasan realisasi bulan berjalan */
.stat-row {
  display: grid; grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem; margin: 0 0 1.25rem;
}
.stat-row > div {
  padding: 0.9rem 1rem; border: 1px solid var(--border-strong); border-radius: var(--radius-md, 10px);
}
.stat-row dt { font-size: var(--fs-sm); font-weight: 500; color: var(--muted); }
.stat-row dd { margin: 0.3rem 0 0; font-size: var(--fs-lg); font-weight: 600; color: var(--ink); }
.stat-row dd.stat-note { margin-top: 0.15rem; font-size: var(--fs-sm); font-weight: 400; color: var(--muted); }
.stat-row dd.stat-note.bad { color: var(--red-dark); font-weight: 600; }
@media (max-width: 720px) {
  .stat-row { grid-template-columns: minmax(0, 1fr); }
}
</style>
