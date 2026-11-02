<script setup lang="ts">
import { computed, onMounted, ref, useId, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api, { formatRupiah } from '../api'
import ReportsHarian from './ReportsHarian.vue'
import ReportsDpk from './ReportsDpk.vue'
import ReportsPiutang from './ReportsPiutang.vue'
import MoreDetails from './MoreDetails.vue'
import Sparkline from './Sparkline.vue'
import { formatRpSingkat, kantorColor, REPORT_KINDS, REPORT_KIND_LABELS } from '../report-helpers'
import { slideTransition } from '../stores/present'

/* ==========================================================================
   LAPORAN KEUANGAN: 5 jenis laporan:
     1) Laporan Aset      -> /api/gl/aset-konsolidasi + /api/gl/aset-perkantor
     2) Laporan Laba Rugi -> /api/gl/laba-rugi-konsolidasi + /api/gl/laba-rugi-perkantor
     3) Laporan Keuangan Harian -> /api/laporan/harian   (komponen ReportsHarian.vue)
     4) Laporan DPK             -> /api/laporan/dpk      (komponen ReportsDpk.vue)
     5) Laporan Piutang         -> /api/laporan/piutang  (komponen ReportsPiutang.vue)
   Jenis 3-5 punya filter & tampilan sendiri di komponennya masing-masing
   (query sumber: be/QueryData/Laporan-Keuangan-*.sql, port di
   be/queries_laporan.py, endpoint /api/laporan/* di be/app.py).
   Untuk jenis GL (1-2), tiap jenis = 1 halaman, 2 menu (urut dari atas):
     - menu 1: konsolidasi SEMUA cabang (kdloc dipaksa '00') + grafik code.html
     - menu 2: rincian PER KANTOR, filter Kantor + tabel detail (kolom Kantor)
               + diagram KOMPARASI antar BPRS (beberapa kantor -> 1 garis,
               tiap BPRS beda warna; urutan: tabel di atas, diagram di bawah)
   Sumber query: be/QueryData/Query1-Aset.sql (4 query), sudah port
   parameterised di be/queries.py. BE TIDAK PERNAH membaca be/schema.sql
   (itu file buatan, jangan dipakai). Endpoint:
     GET /api/gl/{kind}?tahun=YYYY (bulanan)
     atau /api/gl/{kind}?mulai=YYYY&akhir=YYYY (tahunan = RANGE per tahun)
   Data perkantor selalu diambil SEMUA kantor (kdloc=00) sekali fetch;
   filter Kantor tabel = client-side; diagram memakai seluruh baris.
   UI mengikuti fe/Documentation/Laporan-Aset/DESIGN.md + code.html.
   ========================================================================== */

interface GlRow {
  keterangan: string
  judul: string
  thn: string
  bln: string
  saldo: number
  kdloc?: string
  view?: string
}

// ---- Filter global ----
// Jenis: 'aset'/'labarugi' = laporan GL (filter global di halaman ini);
// 'harian'/'dpk'/'piutang' = laporan baru, filter & konten di komponen child
// Disimpan di URL (?jenis=...): deep-link, back/forward browser, dan deck
// slide Present Mode (stores/present.ts) membaca/menulis query yang sama.
const route = useRoute()
const router = useRouter()
const glKind = computed<string>({
  get() {
    const k = route.query.jenis
    if (typeof k === 'string' && (REPORT_KINDS as readonly string[]).includes(k)) return k
    return 'aset'
  },
  set(v) {
    void router.replace({ query: { ...route.query, jenis: v } })
  },
})
const glTahun = ref('2023')
// Range tahun utk mode Tahunan, filter "Tahun" berubah jadi "Dari–s.d."
const glTahunMulai = ref('2021')
const glTahunAkhir = ref('2024')
const glYears = ['2021', '2022', '2023', '2024']
const glGranular = ref<'bulanan' | 'tahunan'>('bulanan')
// Filter Kantor: HANYA utk menu 2 (rincian per kantor); menu 1 selalu '00'
const glKdloc = ref('00')
const glOffices = ref<string[]>([])
const glKonsRows = ref<GlRow[]>([]) // menu 1: konsolidasi semua cabang
const glKantorRows = ref<GlRow[]>([]) // menu 2: rincian per kantor
const glLoading = ref(true)
const glError = ref('')
/** Tabel data terperinci: tersembunyi default, dibuka via tombol More details. */
const glDetKons = ref(false)
const glDetKantor = ref(false)

/** `detail` dari FastAPI (mis. 503 "Database tidak terjangkau …") bila ada. */
function apiErrText(e: unknown, fallback: string): string {
  const d = (e as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail
  return typeof d === 'string' && d ? d : fallback
}

const glKindLabel: Record<string, string> = REPORT_KIND_LABELS

/** Label tab = label laporan tanpa kata "Laporan" (sudah jelas dari halaman). */
const tabLabel = (k: string): string => REPORT_KIND_LABELS[k].replace(/^Laporan /, '')
const REPORT_INTRO: Record<string, string> = {
  aset: 'Posisi aset konsolidasi dan rincian per kantor.',
  labarugi: 'Laba rugi konsolidasi dan rincian per kantor.',
  harian: 'Posisi kas, bank, pembiayaan, dan laba rugi pada tanggal terpilih.',
  dpk: 'Dana pihak ketiga per produk dan kantor.',
  piutang: 'Posisi piutang per golongan dan kantor.',
}

/** Jenis GL pakai filter/tampilan global halaman ini; selain itu tampil di child. */
const isGl = computed(() => glKind.value === 'aset' || glKind.value === 'labarugi')

// Ganti jenis (dropdown atau ganti slide Present Mode) -> filter query berubah,
// watcher ini yang load GL & kembali ke atas. Lewati saat pindah halaman lain
// (route.query ikut berubah selama view masih animasi keluar).
watch(glKind, () => {
  if (route.path !== '/reports') return
  if (isGl.value) void loadGl()
  window.scrollTo({ top: 0 })
})
const glApiBase = computed(() => (glKind.value === 'aset' ? 'aset' : 'laba-rugi'))
const glIsAset = computed(() => glKind.value === 'aset')
const glTitle = computed(() => glKindLabel[glKind.value] ?? glKind.value)

function shortMonth(bln: string): string {
  // bln bisa 'MM' (query/mock) atau 'YYYY-MM', ambil 2 digit bulan terakhir
  const m = bln.length > 2 ? bln.slice(-2) : bln
  const names: Record<string, string> = {
    '01': 'Jan', '02': 'Feb', '03': 'Mar', '04': 'Apr', '05': 'Mei', '06': 'Jun',
    '07': 'Jul', '08': 'Agu', '09': 'Sep', '10': 'Okt', '11': 'Nov', '12': 'Des',
  }
  return names[m] ?? m
}
function glMonthLabel(r: GlRow): string {
  return `${shortMonth(r.bln)} ${r.thn}`
}
// Periode tabel: bulanan = "Mon yyyy" (carry-over = "(awal)");
// tahunan = per tahun dlm range (aset "Des yyyy", laba rugi "Total yyyy")
function glPeriodLabel(r: GlRow): string {
  if (glGranular.value === 'tahunan') return glIsAset.value ? glMonthLabel(r) : `Total ${r.thn}`
  if (r.thn !== glTahun.value) return `${glMonthLabel(r)} (awal)`
  return glMonthLabel(r)
}

// thn/bln/kdloc bisa number di DB asli, dinormalkan ke string saat terima data
async function fetchGl(kind: string, kdloc: string): Promise<GlRow[]> {
  const params: Record<string, string> =
    glGranular.value === 'tahunan'
      ? { mulai: glTahunMulai.value, akhir: glTahunAkhir.value, kdloc, granular: 'tahunan' }
      : { tahun: glTahun.value, kdloc, granular: 'bulanan' }
  const { data } = await api.get(`/api/gl/${kind}`, { params })
  return ((data.rows ?? []) as Array<Record<string, unknown>>).map((r) => ({
    ...r,
    keterangan: String(r.keterangan ?? ''),
    judul: String(r.judul ?? ''),
    thn: String(r.thn ?? ''),
    bln: String(r.bln ?? ''),
    saldo: Number(r.saldo) || 0,
    kdloc: r.kdloc == null ? undefined : String(r.kdloc),
    view: r.view == null ? undefined : String(r.view),
  })) as GlRow[]
}

async function loadGl(): Promise<void> {
  if (!isGl.value) return // jenis non-GL di-fetch komponen child masing-masing
  glLoading.value = true
  glError.value = ''
  try {
    const base = glApiBase.value
    // perkantor SELALU '00' (semua kantor), cukup 1 fetch: tabel filter
    // Kantor client-side, diagram komparasi multi-kantor pakai baris yang sama
    const [kons, kantor] = await Promise.all([
      fetchGl(`${base}-konsolidasi`, '00'),
      fetchGl(`${base}-perkantor`, '00'),
    ])
    glKonsRows.value = kons
    glKantorRows.value = kantor
  } catch (e) {
    glError.value = apiErrText(e, 'Gagal memuat data GL. Pastikan BE jalan.')
    glKonsRows.value = []
    glKantorRows.value = []
  } finally {
    glLoading.value = false
  }
}

async function loadGlOffices(): Promise<void> {
  try {
    const { data } = await api.get('/api/gl/offices')
    glOffices.value = (data as { kdloc: string }[]).map((o) => String(o.kdloc))
    if (!glOffices.value.includes('00')) glOffices.value = ['00', ...glOffices.value]
    if (!glOffices.value.includes(glKdloc.value)) glKdloc.value = '00'
  } catch {
    glOffices.value = ['00', '01', '02', '03']
  }
}


function setGran(g: 'bulanan' | 'tahunan'): void {
  if (glGranular.value === g) return
  glGranular.value = g
  void loadGl()
}

// Range tahun (mode tahunan): clamp Dari <= s.d., lalu reload
function setTahunMulai(v: string): void {
  glTahunMulai.value = v
  if (glTahunMulai.value > glTahunAkhir.value) glTahunAkhir.value = v
  void loadGl()
}
function setTahunAkhir(v: string): void {
  glTahunAkhir.value = v
  if (glTahunAkhir.value < glTahunMulai.value) glTahunMulai.value = v
  void loadGl()
}
// Teks periode utk kartu metric / aria diagram (String cmp aman utk 4 digit)
const glPeriodText = computed(() =>
  glGranular.value === 'bulanan' ? glTahun.value : `${glTahunMulai.value}–${glTahunAkhir.value}`,
)
const glEndYear = computed(() => (glGranular.value === 'bulanan' ? glTahun.value : glTahunAkhir.value))

// Urutan tabel: per kantor dulu (blok kantor), baru thn/bln;
// disamakan dgn ORDER BY query asli (kdloc, thn, bln) apa pun mode mock/real
function sortGl(rows: GlRow[], grouped: boolean): GlRow[] {
  return [...rows].sort((a, b) => {
    if (grouped) {
      const ka = a.kdloc ?? ''
      const kb = b.kdloc ?? ''
      if (ka !== kb) return ka < kb ? -1 : 1
    }
    if (a.thn !== b.thn) return a.thn < b.thn ? -1 : 1
    return a.bln < b.bln ? -1 : a.bln > b.bln ? 1 : 0
  })
}
const keepPeriod = (r: GlRow): boolean =>
  glGranular.value === 'bulanan' || (r.thn >= glTahunMulai.value && r.thn <= glTahunAkhir.value)

const glKonsTable = computed(() => sortGl(glKonsRows.value.filter(keepPeriod), false))
// Tabel per kantor: filter Kantor diaplikasikan CLIENT-side (data sudah semua kantor)
const glKantorTable = computed(() =>
  sortGl(
    glKantorRows.value.filter(
      (r) => keepPeriod(r) && (glKdloc.value === '00' || (r.kdloc ?? '') === glKdloc.value),
    ),
    true,
  ),
)

/* ==========================================================================
   Diagram komparasi antar BPRS (menu 2): beberapa kantor -> 1 diagram GARIS,
   tiap BPRS beda warna. Palet diurutkan per kdloc -> warna stabil antar sesi.
   Sumber: glKantorRows (semua kantor), independen dari filter Kantor tabel.
   Geometri: viewBox 960×340, plot x 64..944 / y 16..304, skala DARI NOL
   (komparasi jujur antar kantor; berbeda dgn bar code.html yang zoom).
   ========================================================================== */
// null = belum pernah dipilih -> default SEMUA kantor tampil
const glCompare = ref<string[] | null>(null)
const glKantors = computed(() =>
  [...new Set(glKantorRows.value.map((r) => r.kdloc ?? '').filter(Boolean))].sort(),
)
const glCompareSel = computed(() =>
  glCompare.value === null
    ? glKantors.value
    : glCompare.value.filter((k) => glKantors.value.includes(k)),
)
/** Warna = kantor, sama persis dgn grafik DPK & Piutang (palet bersama). */
function diagColor(kdloc: string): string {
  return kantorColor(kdloc, glKantors.value)
}
function toggleCompare(k: string): void {
  const cur = [...glCompareSel.value]
  const i = cur.indexOf(k)
  if (i >= 0) cur.splice(i, 1)
  else cur.push(k)
  glCompare.value = cur.sort()
}
function allCompare(): void {
  glCompare.value = null
}
function noneCompare(): void {
  glCompare.value = []
}

interface DiagPt {
  x: number
  y: number
  label: string
  saldo: number
}
interface DiagLine {
  kdloc: string
  color: string
  pts: DiagPt[]
}
interface DiagState {
  lines: DiagLine[]
  xTicks: { x: number; label: string }[]
  grid: { y: number; label: string }[]
  aria: string
  scale: number
  suffix: string
}
const glDiag = computed<DiagState | null>(() => {
  const sel = glCompareSel.value
  if (!sel.length) return null
  const byK = new Map<string, GlRow[]>()
  for (const r of glKantorRows.value) {
    const k = r.kdloc ?? ''
    if (!k) continue
    const arr = byK.get(k)
    if (arr) arr.push(r)
    else byK.set(k, [r])
  }
  const src = sel
    .filter((k) => (byK.get(k)?.length ?? 0) > 0)
    .map((k) => ({ kdloc: k, rows: sortGl(byK.get(k)!, false) }))
  if (!src.length) return null
  const pkeys: string[] = []
  const seen = new Set<string>()
  const pRow = new Map<string, GlRow>()
  for (const l of src) {
    for (const r of l.rows) {
      const key = `${r.thn}-${r.bln}`
      if (!seen.has(key)) {
        seen.add(key)
        pkeys.push(key)
        pRow.set(key, r)
      }
    }
  }
  pkeys.sort()
  const n = pkeys.length
  const X0 = 64
  const X1 = 944
  const Y0 = 16
  const Y1 = 304
  const maxVal = Math.max(...src.flatMap((l) => l.rows.map((r) => r.saldo)))
  const yMax = maxVal > 0 ? maxVal * 1.05 : 1
  const X = (j: number) => (n <= 1 ? (X0 + X1) / 2 : X0 + (j * (X1 - X0)) / (n - 1))
  const Y = (v: number) => Y1 - (v / yMax) * (Y1 - Y0)
  const scale = yMax >= 1e12 ? 1e12 : yMax >= 1e9 ? 1e9 : 1e6
  const suffix = scale === 1e12 ? 'T' : scale === 1e9 ? 'M' : 'Jt'
  return {
    lines: src.map((l) => ({
      kdloc: l.kdloc,
      color: diagColor(l.kdloc),
      pts: l.rows.map((r) => ({
        x: X(pkeys.indexOf(`${r.thn}-${r.bln}`)),
        y: Y(r.saldo),
        label: glPeriodLabel(r),
        saldo: r.saldo,
      })),
    })),
    xTicks: pkeys.map((key, j) => {
      const r = pRow.get(key)!
      if (glGranular.value === 'tahunan') return { x: X(j), label: r.thn }
      return { x: X(j), label: j === 0 || j === n - 1 ? glXLabel(r, true) : shortMonth(r.bln) }
    }),
    grid: [0, 1, 2, 3, 4].map((g) => ({
      y: Y1 - (g / 4) * (Y1 - Y0),
      label:
        g === 0
          ? '0'
          : `${((yMax * g) / 4 / scale).toLocaleString('id-ID', { maximumFractionDigits: 2 })} ${suffix}`,
    })),
    aria: `Diagram garis komparasi ${glTitle.value} ${glPeriodText.value} antar BPRS ${sel.join(', ')}`,
    scale,
    suffix,
  }
})

/* Animasi draw diagram komparasi (kiri -> kanan, awal -> akhir periode):
   clip rect melebar; key = daftar kantor terpilih -> draw ulang saat
   pilihan komparasi ganti (node defs di-remount). uid unik per instance
   (Vue 3.5 useId) agar 2 instance transisi slide tak bentrok id. */
const diagUid = useId()
const diagDrawKey = computed(() => glDiag.value?.lines.map((l) => l.kdloc).join('|') ?? 'none')

/** Label nilai per titik diagram komparasi: format sumbu diagram (Jt/M/T), ≤2 desimal. */
function glDiagLabel(v: number): string {
  const d = glDiag.value
  if (!d) return ''
  return `${(v / d.scale).toLocaleString('id-ID', { maximumFractionDigits: 2 })} ${d.suffix}`
}

// Baris grafik menu 1: bulanan -> 12 bulan tahun berjalan (carry-over utk baseline);
// tahunan -> 1 baris per tahun dlm range. Carry-over = thn < tahun berjalan (aman utk DB asli).
const glBaseline = computed(() => {
  if (glGranular.value !== 'bulanan') return null
  return glKonsRows.value.find((r) => r.thn !== glTahun.value) ?? null
})
const glChartRows = computed(() =>
  glGranular.value === 'bulanan'
    ? glKonsRows.value.filter((r) => r.thn === glTahun.value)
    : glKonsRows.value.filter(keepPeriod),
)
const glMax = computed(() => Math.max(1, ...glChartRows.value.map((r) => r.saldo)))

// Satuan sumbu otomatis: Jt / M (miliar) / T (triliun), angka tetap tabular
const glScale = computed(() => (glMax.value >= 1e12 ? 1e12 : glMax.value >= 1e9 ? 1e9 : 1e6))
const glSuffix = computed(() => (glScale.value === 1e12 ? 'T' : glScale.value === 1e9 ? 'M' : 'Jt'))

// Aset = posisi (stok) -> ambil posisi terakhir. Laba rugi = arus -> jumlahkan.
const glIsArus = computed(() => !glIsAset.value)
const glStok = computed(() => {
  const last = glChartRows.value[glChartRows.value.length - 1]
  return last ? last.saldo : 0
})
const glSum = computed(() => {
  if (glGranular.value === 'bulanan') return glChartRows.value.reduce((s, r) => s + r.saldo, 0)
  // tahunan range: arus diambil tahun AKHIR, jumlah lintas tahun tidak bermakna
  const last = glChartRows.value[glChartRows.value.length - 1]
  return last ? last.saldo : 0
})
const glTotal = computed(() => (glIsArus.value ? glSum.value : glStok.value))
const glTotalLabel = computed(() =>
  glIsArus.value ? `Total ${glGranular.value} ${glEndYear.value}` : `Posisi akhir ${glEndYear.value}`,
)
/** Deret utk sparkline kartu metrik GL: saldo konsolidasi per baris chart
    (periode & sumber = grafik menu 1: tanpa angka rekaan). */
const glTotalSeries = computed<(number | null)[]>(() =>
  glChartRows.value.map((r) => r.saldo),
)
const glLastDelta = computed(() => {
  if (glChartRows.value.length < 2) return null
  const a = glChartRows.value[glChartRows.value.length - 2].saldo
  const b = glChartRows.value[glChartRows.value.length - 1].saldo
  if (!a) return null
  return ((b - a) / a) * 100
})

/* ==========================================================================
   Grafik bar DOM: mengikuti fe/Documentation/Laporan-Aset/code.html
   Section 1 "Pergerakan Posisi Aset Konsolidasi Bulanan":
   baseline bar Des thn lalu (abu) + garis dashed, 12 bar emerald,
   value muncul saat hover, bar terakhir (Des) selalu tampil + highlight,
   legend 2 item, lalu mini breakdown Q1–Q4 vs baseline.
   ========================================================================== */
function glXLabel(r: GlRow, withYear: boolean): string {
  const m = shortMonth(r.bln)
  return withYear ? `${m} '${r.thn.slice(2)}` : m
}
function glCompact(v: number): string {
  const n = (v / glScale.value).toLocaleString('id-ID', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
  return `${n} ${glSuffix.value}`
}

/** Label nilai di atas tiap batang: ≤1 desimal biar muat di slot bar. */
function glBarLabel(v: number): string {
  const n = (v / glScale.value).toLocaleString('id-ID', { maximumFractionDigits: 1 })
  return `${n} ${glSuffix.value}`
}

/* Geometri bar SVG (laba rugi / tahunan): satu sumber koordinat utk batang
   dan labelnya. Lebar viewBox mengikuti panel laporan yang lebar. */
const GB = { W: 1040, H: 300, L: 64, R: 1030, T: 26, B: 264 }
const glSvgGrid = computed(() =>
  [0, 1, 2, 3, 4].map((g) => ({
    y: GB.T + (g * (GB.B - GB.T)) / 4,
    label: `${((glMax.value * (4 - g)) / 4 / glScale.value).toFixed(1)}${glSuffix.value}`,
  })),
)
const glSvgBars = computed(() => {
  const rows = glChartRows.value
  const slot = (GB.R - GB.L) / Math.max(1, rows.length)
  const w = Math.max(4, Math.min(72, slot - 12))
  return rows.map((r, i) => {
    const h = Math.max(3, (r.saldo / glMax.value) * (GB.B - GB.T))
    return {
      r,
      key: `${r.kdloc ?? 'all'}-${r.thn}-${r.bln}`,
      x: GB.L + i * slot + (slot - w) / 2,
      cx: GB.L + i * slot + slot / 2,
      y: GB.B - h,
      w,
      h,
    }
  })
})

interface GlBar {
  key: string
  x: string
  v: string
  h: number
  kind: '' | 'base' | 'last'
}
const glBars = computed<{ list: GlBar[]; baseH: number; baseLabel: string; baseShort: string }>(() => {
  const empty = { list: [] as GlBar[], baseH: 0, baseLabel: '', baseShort: '' }
  const base = glBaseline.value
  if (!glIsAset.value || glGranular.value !== 'bulanan' || !base) return empty
  const months = glChartRows.value
  if (!months.length) return empty
  const all = [base, ...months]
  const vals = all.map((r) => r.saldo)
  const min = Math.min(...vals)
  const max = Math.max(...vals)
  const span = max - min
  // Skala zoom ala code.html: baseline ~36%, puncak 98% (bukan dari nol)
  const h = (v: number) => (span > 0 ? 36 + ((v - min) / span) * 62 : 60)
  const last = all.length - 1
  return {
    list: all.map((row, i) => ({
      key: `${row.thn}-${row.bln}`,
      x: glXLabel(row, i === 0 || i === last),
      v: glCompact(row.saldo),
      h: h(row.saldo),
      kind: i === 0 ? 'base' : i === last ? 'last' : '',
    })),
    baseH: h(base.saldo),
    baseLabel: `${glXLabel(base, true)} Baseline: Rp ${glCompact(base.saldo)}`,
    baseShort: glXLabel(base, true),
  }
})

// Mini breakdown Q1–Q4 vs baseline (code.html, bawah chart)
const glQuarters = computed(() => {
  const b = glBaseline.value
  if (!glBars.value.list.length || !b || !b.saldo) return []
  return (['03', '06', '09', '12'] as const)
    .map((q, i) => {
      const r = glChartRows.value.find((x) => (x.bln.length > 2 ? x.bln.slice(-2) : x.bln) === q)
      const pct = r ? ((r.saldo - b.saldo) / b.saldo) * 100 : null
      return {
        label: `Q${i + 1} ${glTahun.value}${i === 3 ? ' Final' : ' Posisi'}`,
        val: r?.saldo ?? 0,
        pct,
        last: i === 3,
      }
    })
    .filter((x) => x.val > 0)
})
function qPct(p: number | null): string {
  if (p === null) return '–'
  return (p > 0 ? '+' : '') + p.toLocaleString('id-ID', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%'
}

/* ==========================================================================
   3 kolom "Rincian": Pertumbuhan % / Rp / Status Kinerja (mode bulanan)
   Δ = baris ini − baris sebelumnya, dengan aturan:
   - baris carry-over sendiri / baris pertama / ganti kantor -> "–"
   - Aset: Jan dibanding carry-over Des thn lalu
   tahunan: Δ = tahun ini − tahun sebelumnya (YoY, baris pertama range = "–")
   ========================================================================== */
const glHasGrowth = true

interface Growth {
  pct: number | null
  abs: number | null
  status: 'up' | 'flat' | 'down' | null
}
const GROWTH_NULL: Growth = { pct: null, abs: null, status: null }
function growthAt(rows: GlRow[], i: number): Growth {
  if (i <= 0) return GROWTH_NULL
  const r = rows[i]
  const prev = rows[i - 1]
  if (glGranular.value === 'bulanan' && r.thn !== glTahun.value) return GROWTH_NULL // carry-over sendiri
  if ((prev.kdloc ?? '') !== (r.kdloc ?? '')) return GROWTH_NULL // ganti kantor
  if (!prev.saldo) return GROWTH_NULL
  const abs = r.saldo - prev.saldo
  return { abs, pct: (abs / prev.saldo) * 100, status: abs > 0 ? 'up' : abs < 0 ? 'down' : 'flat' }
}
function pctStr(p: number | null): string {
  if (p === null) return '–'
  return (p > 0 ? '+' : '') + p.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + '%'
}
function absStr(a: number | null): string {
  if (a === null) return '–'
  if (a > 0) return `+ ${formatRupiah(a)}`
  if (a < 0) return `- ${formatRupiah(Math.abs(a))}`
  return formatRupiah(0)
}
function statusClass(g: Growth): string {
  return `chip ${g.status === 'up' ? 'up' : g.status === 'down' ? 'down' : 'neutral'}`
}
function statusText(g: Growth): string {
  if (g.status === null) return '–'
  return g.status === 'up' ? 'Tumbuh' : g.status === 'down' ? 'Menurun' : 'Stabil'
}

onMounted(async () => {
  await Promise.all([loadGlOffices(), loadGl()])
})
</script>

<template>
  <div class="page">
    <!-- Konten = 1 slide per jenis laporan; transisi ala PowerPoint (push
         arah-tergantung, mode out-in) hanya aktif saat Present Mode -->
    <Transition :name="slideTransition" mode="out-in">
    <div :key="glKind" class="page-slide">
    <div class="page-head">
      <div>
        <h1>{{ glTitle }}</h1>
        <p>{{ REPORT_INTRO[glKind] }}</p>
      </div>
    </div>

    <!-- Jenis laporan: tab menulis ?jenis lewat glKind (sama spt deck Present) -->
    <nav class="report-tabs" aria-label="Jenis laporan">
      <button
        v-for="k in REPORT_KINDS"
        :key="k"
        type="button"
        :class="{ on: glKind === k }"
        :aria-current="glKind === k ? 'page' : undefined"
        @click="glKind = k"
      >{{ tabLabel(k) }}</button>
    </nav>

    <!-- Filter GL: Tahun (bulanan) / range Dari–s.d. (tahunan) + granularitas;
         Kantor ada di menu 2; laporan lain punya filter di komponennya -->
    <div v-if="isGl" class="toolbar report-filters">
        <div class="filters">
          <label v-if="isGl && glGranular === 'bulanan'">
            Tahun
            <select v-model="glTahun" @change="loadGl">
              <option v-for="y in glYears" :key="y" :value="y">{{ y }}</option>
            </select>
          </label>
          <label v-if="isGl && glGranular === 'tahunan'">
            Dari Tahun
            <select
              :value="glTahunMulai"
              @change="setTahunMulai(($event.target as HTMLSelectElement).value)"
            >
              <option v-for="y in glYears" :key="y" :value="y">{{ y }}</option>
            </select>
          </label>
          <label v-if="isGl && glGranular === 'tahunan'">
            s.d. Tahun
            <select
              :value="glTahunAkhir"
              @change="setTahunAkhir(($event.target as HTMLSelectElement).value)"
            >
              <option v-for="y in glYears" :key="y" :value="y">{{ y }}</option>
            </select>
          </label>
        </div>

        <div class="segmented" role="group" aria-label="Granularitas laporan">
          <button type="button" :class="{ on: glGranular === 'bulanan' }" @click="setGran('bulanan')">
            Bulanan
          </button>
          <button type="button" :class="{ on: glGranular === 'tahunan' }" @click="setGran('tahunan')">
            Tahunan
          </button>
        </div>
    </div>

    <!-- Angka utama: dari menu 1 (konsolidasi semua cabang) -->
    <template v-if="isGl">
    <section class="lead">
      <div>
        <p class="lead-label">{{ glTotalLabel }}</p>
        <p class="lead-value num">{{ glLoading ? '–' : formatRupiah(glTotal) }}</p>
        <p class="lead-note">
          <span v-if="glLastDelta !== null" :class="['chip', glLastDelta >= 0 ? 'up' : 'down']">
            {{ glLastDelta >= 0 ? '▲ +' : '▼ ' }}{{ glLastDelta.toFixed(1) }}%
            {{ glGranular === 'bulanan' ? 'dari bulan lalu' : 'dari tahun lalu' }}
          </span>
          <span v-else class="chip neutral">{{ glIsArus ? 'Arus periode berjalan' : 'Posisi stok' }}</span>
          Konsolidasi semua cabang, {{ glPeriodText }}
        </p>
      </div>
      <div class="lead-spark">
        <Sparkline
          v-if="!glLoading && !glError && glTotalSeries.length > 1"
          :values="glTotalSeries"
          :aria-label="`Tren ${glTotalLabel} per periode`"
        />
      </div>
    </section>

    <!-- ================= MENU 1: KONSOLIDASI SEMUA CABANG ================= -->
    <section class="panel">
      <h2>Konsolidasi Semua Cabang</h2>
      <p class="sub">
        {{ glGranular === 'bulanan' ? 'Per bulan' : 'Per tahun' }}, {{ glPeriodText }}
      </p>
      <p v-if="glLoading" class="muted">Memuat data konsolidasi…</p>
      <p v-else-if="glError" class="alert">{{ glError }}</p>
      <p v-else-if="!glChartRows.length" class="muted">
        Tidak ada data untuk filter ini. Ubah tahun atau pilih Bulanan/Tahunan.
      </p>
      <!-- Aset bulanan: bar DOM mengikuti code.html (baseline + Q1–Q4) -->
      <div v-else-if="glBars.list.length" class="chart-dom">
        <div class="chart-legend">
          <span><i class="swatch s-primary" />Posisi {{ glTahun }} ({{ glSuffix }})</span>
          <span v-if="glBaseline">
            <i class="swatch dashed" aria-hidden="true" />Baseline {{ glBaseline.thn }} ({{ glCompact(glBaseline.saldo) }})
          </span>
        </div>

        <div class="chart-stage">
          <!-- Garis dashed baseline + label (code.html) -->
          <div v-if="glBaseline" class="base-line" :style="{ bottom: glBars.baseH + '%' }">
            <span class="base-tag">{{ glBars.baseLabel }}</span>
          </div>

          <div class="bars">
            <div
              v-for="(b, bi) in glBars.list"
              :key="b.key"
              class="bar-col"
              :class="b.kind"
              :style="{ '--i': bi }"
            >
              <span class="bar-val num">{{ b.v }}</span>
              <div class="bar-fill" :style="{ height: b.h + '%' }" />
              <span class="bar-x">{{ b.x }}</span>
            </div>
          </div>
        </div>

        <!-- Mini breakdown Q1–Q4 vs baseline (code.html) -->
        <div class="q-grid" v-if="glQuarters.length">
          <div v-for="q in glQuarters" :key="q.label" class="q-cell" :class="{ last: q.last }">
            <span class="q-label">{{ q.label }}</span>
            <span class="q-val">Rp {{ glCompact(q.val) }}</span>
            <span class="q-pct" :class="q.pct !== null && q.pct < 0 ? 'neg' : ''">{{ qPct(q.pct) }}<template v-if="q.last"> YoY</template></span>
          </div>
        </div>
      </div>

      <div v-else class="chart-wrap">
        <svg :viewBox="`0 0 ${GB.W} ${GB.H}`" role="img" :aria-label="`Grafik ${glTitle} ${glPeriodText}`">
          <g v-for="g in glSvgGrid" :key="g.y">
            <line class="l-grid" :x1="GB.L" :y1="g.y" :x2="GB.R" :y2="g.y" />
            <text class="t-axis" :x="GB.L - 8" :y="g.y + 4" text-anchor="end" font-size="12">{{ g.label }}</text>
          </g>
          <g v-for="(b, i) in glSvgBars" :key="b.key" :style="{ '--i': i }">
            <rect data-bar class="svg-bar s1" :x="b.x" :width="b.w" :y="b.y" :height="b.h" rx="4">
              <title>{{ glPeriodLabel(b.r) }}: {{ formatRupiah(b.r.saldo) }}</title>
            </rect>
            <text
              v-if="glChartRows.length <= 13"
              class="svg-bar-val t-val"
              :x="b.cx" :y="b.y - 6"
              text-anchor="middle" font-size="12.5"
            >{{ glBarLabel(b.r.saldo) }}</text>
            <text
              v-if="glChartRows.length <= 13"
              class="svg-bar-x t-axis"
              :x="b.cx" :y="GB.B + 22"
              text-anchor="middle" font-size="12.5"
            >{{ glGranular === 'tahunan' ? b.r.thn : shortMonth(b.r.bln) }}</text>
          </g>
        </svg>
        <div class="chart-legend">
          <span><i class="swatch s-primary" />{{ glTitle }}, {{ glPeriodText }}</span>
        </div>
      </div>

      <!-- Data terperinci konsolidasi: tersembunyi default, tombol More details -->
      <template v-if="!glLoading && !glError && glKonsTable.length">
        <MoreDetails id="det-gl-kons" :open="glDetKons" @toggle="glDetKons = !glDetKons">
        <div class="table-scroll">

        <table>
          <thead>
            <tr>
              <th>Periode</th>
              <th class="ta-r">Saldo</th>
              <th v-if="glHasGrowth" class="ta-r">Pertumbuhan (%)</th>
              <th v-if="glHasGrowth" class="ta-r">Pertumbuhan (Rp)</th>
              <th v-if="glHasGrowth" class="ta-c">Status Kinerja</th>
              <th>Keterangan</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(r, i) in glKonsTable" :key="i">
              <td>{{ glPeriodLabel(r) }}</td>
              <td class="ta-r num" :title="formatRupiah(r.saldo)">{{ formatRpSingkat(r.saldo) }}</td>
              <template v-if="glHasGrowth">
                <td class="ta-r num" :class="growthAt(glKonsTable, i).pct !== null ? (growthAt(glKonsTable, i).pct! >= 0 ? 'g-up' : 'g-down') : 'muted'">
                  {{ pctStr(growthAt(glKonsTable, i).pct) }}
                </td>
                <td class="ta-r num" :class="growthAt(glKonsTable, i).abs !== null ? (growthAt(glKonsTable, i).abs! >= 0 ? 'g-up' : 'g-down') : 'muted'">
                  {{ absStr(growthAt(glKonsTable, i).abs) }}
                </td>
                <td class="ta-c">
                  <span :class="statusClass(growthAt(glKonsTable, i))">
                    <i class="dot" aria-hidden="true" />
                    {{ statusText(growthAt(glKonsTable, i)) }}
                  </span>
                </td>
              </template>
              <td class="muted small">{{ r.keterangan }}</td>
            </tr>
          </tbody>
        </table>
        </div>
        </MoreDetails>
      </template>
    </section>

    <!-- ================= MENU 2: RINCIAN PER KANTOR ================= -->
    <section class="panel">
      <div class="toolbar">
        <div>
          <h2>Rincian per Kantor</h2>
        </div>
        <div class="filters">
          <label>
            Kantor
            <select v-model="glKdloc">
              <option v-for="k in glOffices" :key="k" :value="k">{{ k === '00' ? '00 (Semua)' : k }}</option>
            </select>
          </label>
        </div>
      </div>

      <p v-if="glLoading" class="muted">Memuat data per kantor…</p>
      <p v-else-if="glError" class="alert">{{ glError }}</p>
      <p v-else-if="!glKantorTable.length" class="muted">Belum ada data untuk filter ini. Coba ganti tahun, rentang tanggal, atau kantor.</p>

      <!-- ============ Diagram komparasi antar BPRS (grafik menu 2) ============
           Beberapa kantor dalam 1 diagram garis, tiap Lokasi beda warna garis -->
      <div v-if="!glLoading && !glError && glKantors.length" class="compare">
        <div class="compare-head">
          <div>
            <h3>Komparasi Antar Lokasi</h3>
            <p class="muted small">
              Pilih lokasi untuk dibandingkan. Tiap lokasi punya warna garis sendiri,
              dan periodenya mengikuti filter di atas.
            </p>
          </div>
          <div class="compare-actions">
            <button type="button" class="btn-ghost" @click="allCompare">Pilih semua</button>
            <button type="button" class="btn-ghost" @click="noneCompare">Kosongkan</button>
          </div>
        </div>

        <div class="compare-chips" role="group" aria-label="Pilih BPRS untuk diagram komparasi">
          <button
            v-for="k in glKantors"
            :key="k"
            type="button"
            class="compare-chip"
            :class="{ on: glCompareSel.includes(k) }"
            :aria-pressed="glCompareSel.includes(k)"
            @click="toggleCompare(k)"
          >
            <i class="swatch" :style="{ background: diagColor(k) }" aria-hidden="true" />
            {{ k }}
          </button>
        </div>

        <div v-if="glDiag" class="chart-wrap diag">
          <svg viewBox="0 0 960 340" role="img" :aria-label="glDiag.aria">
            <!-- Clip animasi draw (kiri -> kanan); key = kantor terpilih -> draw ulang saat pilihan ganti -->
            <defs :key="diagDrawKey">
              <clipPath :id="`gldiag-${diagUid}`" clipPathUnits="userSpaceOnUse">
                <rect class="diag-clip-rect" x="0" y="0" width="960" height="340" style="--diag-w: 960px" />
              </clipPath>
            </defs>
            <g v-for="g in glDiag.grid" :key="g.y">
              <line class="l-grid" x1="64" :y1="g.y" x2="944" :y2="g.y" />
              <text class="t-axis" x="58" :y="g.y + 4" text-anchor="end" font-size="12">{{ g.label }}</text>
            </g>
            <g v-for="(t, ti) in glDiag.xTicks" :key="t.x">
              <text
                class="t-axis" :x="t.x" y="328" font-size="12"
                :text-anchor="ti === 0 ? 'start' : ti === glDiag.xTicks.length - 1 ? 'end' : 'middle'"
              >{{ t.label }}</text>
            </g>
            <g
              v-for="l in glDiag.lines"
              :key="l.kdloc"
              :clip-path="`url(#gldiag-${diagUid})`"
            >
              <polyline
                :points="l.pts.map((p) => `${p.x},${p.y}`).join(' ')"
                fill="none"
                :stroke="l.color"
                stroke-width="2.5"
                stroke-linejoin="round"
                stroke-linecap="round"
              />
              <g v-for="(p, pi) in l.pts" :key="`${l.kdloc}-${p.label}`">
                <circle :cx="p.x" :cy="p.y" r="3" :fill="l.color">
                  <title>BPRS {{ l.kdloc }}, {{ p.label }}: {{ formatRupiah(p.saldo) }}</title>
                </circle>
                <!-- Nilai terlihat di atas tiap titik (halo surface biar kebaca di atas garis) -->
                <text
                  class="t-val t-halo"
                  :x="p.x" :y="p.y - 8"
                  :text-anchor="pi === 0 ? 'start' : pi === l.pts.length - 1 ? 'end' : 'middle'"
                  font-size="11.5"
                >{{ glDiagLabel(p.saldo) }}</text>
              </g>
            </g>
          </svg>
          <div class="chart-legend">
            <span v-for="l in glDiag.lines" :key="l.kdloc">
              <i class="swatch" :style="{ background: l.color }" aria-hidden="true" />
              BPRS {{ l.kdloc }}
            </span>
          </div>
        </div>
        <p v-else-if="glKantors.length && !glCompareSel.length" class="muted small">Pilih minimal 1 BPRS untuk menampilkan diagram komparasi.</p>
      </div>

      <!-- Data terperinci per kantor: tersembunyi default, tombol More details -->
      <template v-if="!glLoading && !glError && glKantorTable.length">
        <MoreDetails id="det-gl-kantor" :open="glDetKantor" @toggle="glDetKantor = !glDetKantor">
        <div class="table-scroll">
          <table>
          <thead>
            <tr>
              <th>Kantor</th>
              <th>Periode</th>
              <th class="ta-r">Saldo</th>
              <th v-if="glHasGrowth" class="ta-r">Pertumbuhan (%)</th>
              <th v-if="glHasGrowth" class="ta-r">Pertumbuhan (Rp)</th>
              <th v-if="glHasGrowth" class="ta-c">Status Kinerja</th>
              <th>Keterangan</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(r, i) in glKantorTable" :key="i">
              <td class="num">{{ r.kdloc ?? '–' }}</td>
              <td>{{ glPeriodLabel(r) }}</td>
              <td class="ta-r num" :title="formatRupiah(r.saldo)">{{ formatRpSingkat(r.saldo) }}</td>
              <template v-if="glHasGrowth">
                <td class="ta-r num" :class="growthAt(glKantorTable, i).pct !== null ? (growthAt(glKantorTable, i).pct! >= 0 ? 'g-up' : 'g-down') : 'muted'">
                  {{ pctStr(growthAt(glKantorTable, i).pct) }}
                </td>
                <td class="ta-r num" :class="growthAt(glKantorTable, i).abs !== null ? (growthAt(glKantorTable, i).abs! >= 0 ? 'g-up' : 'g-down') : 'muted'">
                  {{ absStr(growthAt(glKantorTable, i).abs) }}
                </td>
                <td class="ta-c">
                  <span :class="statusClass(growthAt(glKantorTable, i))">
                    <i class="dot" aria-hidden="true" />
                    {{ statusText(growthAt(glKantorTable, i)) }}
                  </span>
                </td>
              </template>
              <td class="muted small">{{ r.keterangan }}</td>
            </tr>
          </tbody>
          </table>
        </div>
        </MoreDetails>
      </template>
    </section>
    </template><!-- /isGl -->

    <!-- Laporan non-GL: filter & konten masing-masing di komponen child -->
    <template v-else>
      <ReportsHarian v-if="glKind === 'harian'" />
      <ReportsDpk v-else-if="glKind === 'dpk'" />
      <ReportsPiutang v-else-if="glKind === 'piutang'" />
    </template>
    </div><!-- /page-slide -->
    </Transition>

    <!-- Nav slideshow dipindah ke App.vue: deck lintas menu (Dashboard,
         5 laporan, Likuiditas, Pembiayaan) -> tampil di semua halaman. -->
  </div>
</template>
