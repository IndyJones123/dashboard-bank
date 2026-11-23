<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, KANTOR_PALETTE, shortMonth } from '../report-helpers'
import RpValue from './RpValue.vue'
import {
  KOL, RISK_COLORS, type Row, dateLabel, intText, lastMonth, monthLabel, npfOf, num, pctText, sumOf, sysDate, toPeriode,
} from '../pby-helpers'
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'
import PbyTable, { type PbyCol } from './PbyTable.vue'
import PbyList from './PbyList.vue'
import PbyStack, { type StackSeg } from './PbyStack.vue'

/* ==========================================================================
   PEMBIAYAAN · LIST SALDO
   Sumber (be/QueryData/pembiayaan, dieksekusi apa adanya lewat BE):
     Kolektibilitas & NPF : Pembiayaan NPF berjalan.sql / NPF Bulan.sql
     Realisasi            : 001 Realisasi Berjalan.sql / 002 Realisasi Perbulan.sql
     OS per bulan         : Pembiayaan OS Bulan.sql
   Tiap query punya seksi "Lokasi & Produk" dan "AO" -> toggle tampilan.
   ========================================================================== */

const w = useWidgets('pembiayaan-saldo')

type Mode = 'berjalan' | 'bulan'
type View = 'lokasi' | 'ao'

interface Block {
  mode: Mode
  bulan: string
  view: View
  loading: boolean
  error: string
  lokasi: Row[]
  ao: Row[]
}
const mk = (): Block => ({ mode: 'berjalan', bulan: lastMonth(), view: 'lokasi', loading: true, error: '', lokasi: [], ao: [] })

const npf = reactive(mk())
const real = reactive(mk())

async function loadBlock(b: Block, url: string, label: string): Promise<void> {
  b.loading = true
  b.error = ''
  try {
    const params = b.mode === 'bulan' ? { periode: toPeriode(b.bulan) } : {}
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[] }>(url, { params, timeout: 60000 })
    b.lokasi = data.lokasi ?? []
    b.ao = data.ao ?? []
  } catch (e) {
    b.lokasi = []
    b.ao = []
    b.error = apiErrText(e, `Gagal memuat ${label}. Pastikan BE jalan.`)
  } finally {
    b.loading = false
  }
}
const loadNpf = (): Promise<void> => loadBlock(npf, '/api/pembiayaan/npf', 'kolektibilitas & NPF')
const loadReal = (): Promise<void> => loadBlock(real, '/api/pembiayaan/realisasi', 'realisasi pembiayaan')

const periodText = (b: Block, now: string): string => (b.mode === 'bulan' ? `Akhir ${monthLabel(b.bulan)}` : now)

/* ---------- Kolektibilitas & NPF ---------- */
const npfRows = computed(() => (npf.view === 'lokasi' ? npf.lokasi : npf.ao))
const totalOs = computed(() => sumOf(npf.lokasi, 'os'))
const totalNpf = computed(() => npfOf(npf.lokasi))
const kolCols: PbyCol[] = [
  ...KOL.map((k) => ({ key: k.key, label: `${k.label} ${k.name === 'Dalam Perhatian Khusus' ? 'DPK' : k.name}`, fmt: 'rp' as const, group: 'Kolektibilitas (Rp)' })),
  { key: 'os', label: 'Outstanding', fmt: 'rp' },
  { key: 'npf', label: 'NPF', fmt: 'pct', sum: false },
]
const npfCols = computed<PbyCol[]>(() =>
  npf.view === 'lokasi'
    ? [
        { key: 'nmcabang', label: 'Kantor', sub: 'kdloc' },
        { key: 'ket', label: 'Produk', sub: 'kdprd' },
        ...kolCols,
      ]
    : [{ key: 'nmao', label: 'AO Handle', sub: 'kdaoh' }, ...kolCols],
)
const npfOverride = (rows: Row[]): Row => ({ npf: npfOf(rows) })
const kolSegs = computed<StackSeg[]>(() =>
  KOL.map((k, i) => ({ key: k.key, label: `${k.label} ${k.name}`, value: sumOf(npf.lokasi, k.key), color: RISK_COLORS[i] })),
)

/* ---------- Realisasi ---------- */
const realRows = computed(() => (real.view === 'lokasi' ? real.lokasi : real.ao))
const realCols = computed<PbyCol[]>(() => [
  ...(real.view === 'lokasi'
    ? [
        { key: 'nmkantor', label: 'Kantor', sub: 'kdloc' },
        { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
      ]
    : [{ key: 'nmao', label: 'AO', sub: 'kdaoh' }]),
  { key: 'qty_noa', label: 'NOA', fmt: 'int', group: 'Nasabah Baru' },
  { key: 'plf_noa', label: 'Plafon (Rp)', fmt: 'rp', group: 'Nasabah Baru' },
  { key: 'qty', label: 'NOA', fmt: 'int', group: 'Nasabah Lama' },
  { key: 'plf', label: 'Plafon (Rp)', fmt: 'rp', group: 'Nasabah Lama' },
])
const realNoa = computed(() => sumOf(real.lokasi, 'qty_noa') + sumOf(real.lokasi, 'qty'))
const realPlf = computed(() => sumOf(real.lokasi, 'plf_noa') + sumOf(real.lokasi, 'plf'))

/* ---------- OS per bulan: 1 cabang dipilih via dropdown ----------
   Tabel = rincian per produk bulan 1..12 utk cabang terpilih;
   grafik batang di bawahnya = total cabang itu per bulan (tanpa komparasi). */
const BLN = Array.from({ length: 12 }, (_, i) => `bln${String(i + 1).padStart(2, '0')}`)
const osTahun = ref(String(new Date().getFullYear()))
const osYears = computed(() => {
  const top = Math.max(new Date().getFullYear(), Number(tgl.value?.slice(0, 4) ?? 0))
  return Array.from({ length: 8 }, (_, i) => String(top - i))
})
const os = reactive({ loading: true, error: '', rows: [] as Row[] })
/** kdloc cabang terpilih (default: cabang pertama pada data). */
const osCabang = ref('')

async function loadOs(first = false): Promise<void> {
  os.loading = true
  os.error = ''
  try {
    for (;;) {
      const { data } = await api.get<{ lokasi?: Row[] }>('/api/pembiayaan/os', {
        params: { tahun: osTahun.value }, timeout: 60000,
      })
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
const osKantors = computed(() => [...new Set(os.rows.map((r) => String(r.kdloc)))].sort())
const osKantorName = (k: string): string =>
  String(os.rows.find((r) => String(r.kdloc) === k)?.nmcabang ?? `Kantor ${k}`)
// Cabang terpilih harus selalu ada di daftar (data baru / ganti tahun)
watch(osKantors, (list) => {
  if (list.length && !list.includes(osCabang.value)) osCabang.value = list[0]
})
const osCabangRows = computed(() => os.rows.filter((r) => String(r.kdloc) === osCabang.value))
const osCols: PbyCol[] = [
  { key: 'ket', label: 'Produk', sub: 'kdprd' },
  ...BLN.map((b, i) => ({ key: b, label: shortMonth(String(i + 1)), fmt: 'rp' as const })),
]

/** Label ringkas utk sumbu/atas batang: M = miliar, Jt = juta. */
function fmtOs(v: number): string {
  const s = Math.abs(v)
  const unit = s >= 1e9 ? 'M' : s >= 1e6 ? 'Jt' : s >= 1e3 ? 'rb' : ''
  const n =
    s >= 1e9 ? (s / 1e9).toLocaleString('id-ID', { maximumFractionDigits: 1 })
    : s >= 1e6 ? (s / 1e6).toLocaleString('id-ID', { maximumFractionDigits: 1 })
    : s >= 1e3 ? String(Math.round(s / 1e3))
    : String(Math.round(s))
  return `${n}${unit}`
}

/* Filter produk utk grafik batang ('all' | kdprd). Tabel tetap rincian semua produk. */
const osProduk = ref('all')
const osProds = computed(() => {
  const map = new Map<string, string>()
  for (const r of osCabangRows.value) map.set(String(r.kdprd), String(r.ket))
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([kdprd, ket]) => ({ kdprd, ket }))
})
// Filter harus valid utk cabang/tahun terpilih (data berganti -> kembali 'Semua')
watch(osProds, (list) => {
  if (osProduk.value !== 'all' && !list.some((p) => p.kdprd === osProduk.value)) osProduk.value = 'all'
})
const osChartRows = computed(() =>
  osProduk.value === 'all'
    ? osCabangRows.value
    : osCabangRows.value.filter((r) => String(r.kdprd) === osProduk.value),
)
/** Warna produk: palet data-encoding CVD-safe, identik dgn PbyList. */
function osProdColor(kdprd: string): string {
  const i = osProds.value.findIndex((p) => p.kdprd === kdprd)
  return KANTOR_PALETTE[(i < 0 ? 0 : i) % KANTOR_PALETTE.length]
}
/** Produk yang membentuk batang = legenda. */
const osLegend = computed(() =>
  osProduk.value === 'all' ? osProds.value : osProds.value.filter((p) => p.kdprd === osProduk.value),
)

interface OsSeg { ket: string; color: string; y: number; h: number; v: number }
interface OsBar { bulan: string; label: string; x: number; segs: OsSeg[]; top: number; total: number; text: string }
/** Batang bertumpuk per produk: tinggi tumpukan = total bulan (skala dari nol),
    segmen kosong (0) dilewat; tinggi minimum 1px supaya warna produk tetap terbaca. */
const osBars = computed<OsBar[]>(() => {
  const rows = osChartRows.value
  const totals = BLN.map((b) => sumOf(rows, b))
  const max = Math.max(...totals, 1)
  const prods = osLegend.value
  return BLN.map((bulan, i) => {
    let y = 160
    const segs: OsSeg[] = []
    for (const p of prods) {
      const v = sumOf(rows.filter((r) => String(r.kdprd) === p.kdprd), bulan)
      if (v <= 0) continue
      const h = Math.max(1, (v / max) * 120)
      y -= h
      segs.push({ ket: p.ket, color: osProdColor(p.kdprd), y, h, v })
    }
    return {
      bulan,
      label: shortMonth(String(i + 1)),
      x: 46 + i * 42,
      segs,
      top: segs.length ? segs[segs.length - 1].y : 160,
      total: totals[i],
      text: fmtOs(totals[i]),
    }
  })
})
const osMaxVal = computed(() => Math.max(...BLN.map((b) => sumOf(osChartRows.value, b))))
/** Gerbang section: cabang punya data (tabel tetap tampil walau filter produk kosong). */
const osHasData = computed(() => osCabangRows.value.some((r) => BLN.some((b) => num(r[b]) !== 0)))
/** Grafik ada isi setelah filter produk dipakai. */
const osChartHasData = computed(() => osBars.value.some((b) => b.total > 0))

const subLabel = (key: string) => (r: Row): string => `Subtotal ${String(r[key] ?? '')}`

/** Tanggal sistem DB: nilai awal bulan (bulan sebelumnya) & tahun OS. */
const tgl = ref<string | null>(null)

onMounted(async () => {
  void loadNpf()
  void loadReal()
  tgl.value = await sysDate()
  if (tgl.value) {
    npf.bulan = lastMonth(tgl.value)
    real.bulan = lastMonth(tgl.value)
    osTahun.value = tgl.value.slice(0, 4)
  }
  void loadOs(true)
})
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>List Saldo</h1>
        <p>
          Outstanding, kolektibilitas, NPF, dan realisasi pembiayaan per kantor, produk, dan AO.
          <template v-if="tgl">Tanggal sistem: <strong>{{ dateLabel(tgl) }}</strong>.</template>
        </p>
      </div>
    </div>

    <WidgetNotice :w="w" />
    <div class="wgrid">
      <section v-if="w.show('angka-utama')" class="w lead-part hero" :style="w.style('angka-utama')">
        <p class="lead-label">Outstanding Pembiayaan</p>
        <p class="lead-value num"><RpValue :value="npf.loading ? null : Math.round(totalOs)" /></p>
        <p class="lead-note">{{ periodText(npf, 'Posisi berjalan') }}, {{ intText(npf.lokasi.length) }} kombinasi kantor dan produk</p>
      </section>
      <section v-if="w.show('ringkasan')" class="w lead-part" :style="w.style('ringkasan')">
        <dl class="ledger">
          <div>
            <dt>NPF <small>(Kol 3 + 4 + 5) ÷ outstanding, {{ periodText(npf, 'posisi berjalan').toLowerCase() }}</small></dt>
            <dd class="num" :class="totalNpf != null && totalNpf > 5 ? 'g-down' : ''">{{ npf.loading ? '–' : pctText(totalNpf) }}</dd>
          </div>
          <div>
            <dt>Realisasi <small>{{ real.mode === 'bulan' ? monthLabel(real.bulan) : 'Bulan berjalan' }}, {{ real.loading ? '–' : intText(realNoa) }} NOA</small></dt>
            <dd class="num"><RpValue :value="real.loading ? null : Math.round(realPlf)" /></dd>
          </div>
        </dl>
      </section>

      <!-- Kolektibilitas & NPF -->
      <section v-if="w.show('kolektibilitas')" class="w panel" :style="w.style('kolektibilitas')">
        <div class="pby-head">
          <div>
            <h2>Kolektibilitas &amp; NPF</h2>
            <p class="sub">{{ periodText(npf, 'Posisi berjalan (data hari ini)') }}. Nilai = outstanding pokok.</p>
          </div>
          <div class="pby-ctrl filters">
            <div class="segmented" role="group" aria-label="Periode kolektibilitas">
              <button type="button" :class="{ on: npf.mode === 'berjalan' }" @click="npf.mode = 'berjalan'; loadNpf()">Berjalan</button>
              <button type="button" :class="{ on: npf.mode === 'bulan' }" @click="npf.mode = 'bulan'; loadNpf()">Akhir bulan</button>
            </div>
            <input
              v-if="npf.mode === 'bulan'" v-model="npf.bulan" type="month" aria-label="Bulan kolektibilitas"
              @change="npf.bulan && loadNpf()"
            />
            <div class="segmented" role="group" aria-label="Kelompokkan kolektibilitas">
              <button type="button" :class="{ on: npf.view === 'lokasi' }" @click="npf.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: npf.view === 'ao' }" @click="npf.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="npf.loading" class="muted">Memuat kolektibilitas…</p>
        <p v-else-if="npf.error" class="alert">{{ npf.error }}</p>
        <template v-else>
          <PbyStack :segs="kolSegs" label="Komposisi outstanding per kolektibilitas" />
          <PbyList
            :cols="npfCols" :rows="npfRows" :total-override="npfOverride" head-key="os"
            :subtotal-by="npf.view === 'lokasi' ? 'kdloc' : undefined"
            :subtotal-label="subLabel('nmcabang')"
          />
        </template>
      </section>

      <!-- Realisasi -->
      <section v-if="w.show('realisasi')" class="w panel" :style="w.style('realisasi')">
        <div class="pby-head">
          <div>
            <h2>Realisasi Pembiayaan</h2>
            <p class="sub">
              Pencairan (dropping) {{ real.mode === 'bulan' ? monthLabel(real.bulan) : 'bulan berjalan' }}.
              Nasabah baru = CIF dibuka pada bulan yang sama.
            </p>
          </div>
          <div class="pby-ctrl filters">
            <div class="segmented" role="group" aria-label="Periode realisasi">
              <button type="button" :class="{ on: real.mode === 'berjalan' }" @click="real.mode = 'berjalan'; loadReal()">Bulan berjalan</button>
              <button type="button" :class="{ on: real.mode === 'bulan' }" @click="real.mode = 'bulan'; loadReal()">Pilih bulan</button>
            </div>
            <input
              v-if="real.mode === 'bulan'" v-model="real.bulan" type="month" aria-label="Bulan realisasi"
              @change="real.bulan && loadReal()"
            />
            <div class="segmented" role="group" aria-label="Kelompokkan realisasi">
              <button type="button" :class="{ on: real.view === 'lokasi' }" @click="real.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: real.view === 'ao' }" @click="real.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="real.loading" class="muted">Memuat realisasi…</p>
        <p v-else-if="real.error" class="alert">{{ real.error }}</p>
        <PbyList
          v-else :cols="realCols" :rows="realRows"
          :subtotal-by="real.view === 'lokasi' ? 'kdloc' : undefined"
          :subtotal-label="subLabel('nmkantor')"
          empty="Belum ada pencairan pada periode ini."
        />
      </section>

      <!-- OS per bulan: pilih 1 cabang -> tabel per produk lalu grafik batang cabang itu -->
      <section v-if="w.show('os-bulanan')" class="w panel" :style="w.style('os-bulanan')">
        <div class="pby-head">
          <div>
            <h2>Outstanding per Bulan</h2>
            <p class="sub">Outstanding pokok akhir bulan {{ osTahun }}{{ osCabang ? `, ${osKantorName(osCabang)}` : '' }}, per produk.</p>
          </div>
          <div class="pby-ctrl filters">
            <label>
              Kantor
              <select v-model="osCabang" :disabled="!osKantors.length">
                <option v-for="k in osKantors" :key="k" :value="k">{{ osKantorName(k) }}</option>
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
        <p v-else-if="!osHasData" class="muted">Belum ada data akhir bulan untuk {{ osTahun }}{{ osCabang ? ` di ${osKantorName(osCabang)}` : '' }}.</p>
        <template v-else>
          <PbyTable :cols="osCols" :rows="osCabangRows" empty="Belum ada data produk pada kantor ini." />
          <div class="pby-ctrl filters" style="margin-top: 1rem">
            <label>
              Produk
              <select v-model="osProduk" :disabled="!osProds.length">
                <option value="all">Semua produk</option>
                <option v-for="p in osProds" :key="p.kdprd" :value="p.kdprd">{{ p.ket }}</option>
              </select>
            </label>
            <ul v-if="osChartHasData" class="os-legend" aria-label="Warna produk">
              <li v-for="p in osLegend" :key="p.kdprd">
                <i :style="{ background: osProdColor(p.kdprd) }" aria-hidden="true" />{{ p.ket }}
              </li>
            </ul>
          </div>
          <div v-if="osChartHasData" class="chart-wrap" style="margin-top: 0.75rem">
            <svg viewBox="0 0 560 180" role="img" :aria-label="`Grafik batang outstanding ${osKantorName(osCabang)} ${osTahun}`">
              <g v-for="g in [0, 1, 2, 3, 4]" :key="g">
                <line class="l-grid" x1="44" :y1="40 + g * 30" x2="550" :y2="40 + g * 30" />
                <text class="t-axis" x="38" :y="44 + g * 30" text-anchor="end" font-size="10">
                  {{ g === 4 ? '0' : fmtOs(osMaxVal * (4 - g) / 4) }}
                </text>
              </g>
              <line class="l-base" x1="44" y1="160" x2="550" y2="160" />
              <g v-for="(b, bi) in osBars" :key="b.bulan">
                <g class="svg-bar" :style="{ '--i': bi }">
                  <rect
                    v-for="s in b.segs" :key="s.ket"
                    :x="b.x" width="26" :y="s.y" :height="s.h" :fill="s.color"
                  >
                    <title>{{ b.label }} · {{ s.ket }}: {{ formatRupiah(s.v) }}</title>
                  </rect>
                </g>
                <text class="svg-bar-val t-val" :x="b.x + 13" :y="b.top - 5" text-anchor="middle" font-size="8.5" :style="{ '--i': bi }">{{ b.text }}</text>
                <text class="svg-bar-x t-axis" :x="b.x + 13" y="175" text-anchor="middle" font-size="10" :style="{ '--i': bi }">{{ b.label }}</text>
              </g>
            </svg>
          </div>
          <p v-else class="muted" style="margin-top: 0.75rem">Tidak ada data utk produk ini pada kantor/tahun terpilih.</p>
          <p class="note">Batang bertumpuk = total outstanding per bulan, dipecah per produk (warna = produk, lihat legenda). Pilih Produk utk menyaring grafik; tabel di atas tetap menampilkan semua produk.</p>
        </template>
      </section>
    </div>
  </div>
</template>

<style scoped>
/* Legenda warna produk di samping dropdown filter grafik */
.os-legend {
  display: flex; flex-wrap: wrap; gap: 0.35rem 1rem;
  margin: 0; padding: 0; list-style: none;
  font-size: var(--fs-sm); color: var(--muted);
}
.os-legend li { display: inline-flex; align-items: center; gap: 0.4rem; }
.os-legend i { width: 10px; height: 10px; border-radius: 3px; flex: none; }
</style>
