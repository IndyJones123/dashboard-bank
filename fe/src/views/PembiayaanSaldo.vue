<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, kantorColor, shortMonth } from '../report-helpers'
import {
  KOL, RISK_COLORS, type Row, dateLabel, intText, lastMonth, monthLabel, npfOf, num, pctText, sumOf, sysDate, toPeriode,
} from '../pby-helpers'
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'
import PbyTable, { type PbyCol } from './PbyTable.vue'
import PbyStack, { type StackSeg } from './PbyStack.vue'
import LineChart, { type LineSerie } from './LineChart.vue'

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

/* ---------- OS per bulan ---------- */
const BLN = Array.from({ length: 12 }, (_, i) => `bln${String(i + 1).padStart(2, '0')}`)
const osTahun = ref(String(new Date().getFullYear()))
const osYears = computed(() => {
  const top = Math.max(new Date().getFullYear(), Number(tgl.value?.slice(0, 4) ?? 0))
  return Array.from({ length: 8 }, (_, i) => String(top - i))
})
const os = reactive({ loading: true, error: '', rows: [] as Row[] })

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
const osCols: PbyCol[] = [
  { key: 'nmcabang', label: 'Kantor', sub: 'kdloc' },
  { key: 'ket', label: 'Produk', sub: 'kdprd' },
  ...BLN.map((b, i) => ({ key: b, label: shortMonth(String(i + 1)), fmt: 'rp' as const })),
]
const osKantors = computed(() => [...new Set(os.rows.map((r) => String(r.kdloc)))].sort())
const osSeries = computed<LineSerie[]>(() =>
  osKantors.value.map((k) => {
    const rows = os.rows.filter((r) => String(r.kdloc) === k)
    const name = String(rows[0]?.nmcabang ?? `Kantor ${k}`)
    return {
      key: k,
      label: name,
      color: kantorColor(k, osKantors.value),
      // Bulan tanpa snapshot EOM -> SUM 0 di query: tampil putus, bukan jatuh ke nol
      values: BLN.map((b) => sumOf(rows, b) || null),
    }
  }),
)
const osHasData = computed(() => osSeries.value.some((s) => s.values.some((v) => v != null)))

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
        <p class="lead-value num">{{ npf.loading ? '–' : formatRupiah(Math.round(totalOs)) }}</p>
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
            <dd class="num">{{ real.loading ? '–' : formatRupiah(Math.round(realPlf)) }}</dd>
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
          <PbyTable
            :cols="npfCols" :rows="npfRows" :total-override="npfOverride"
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
        <PbyTable
          v-else :cols="realCols" :rows="realRows"
          :subtotal-by="real.view === 'lokasi' ? 'kdloc' : undefined"
          :subtotal-label="subLabel('nmkantor')"
          empty="Belum ada pencairan pada periode ini."
        />
      </section>

      <!-- OS per bulan -->
      <section v-if="w.show('os-bulanan')" class="w panel" :style="w.style('os-bulanan')">
        <div class="pby-head">
          <div>
            <h2>Outstanding per Bulan</h2>
            <p class="sub">Outstanding pokok akhir bulan {{ osTahun }}, per kantor dan produk.</p>
          </div>
          <div class="pby-ctrl filters">
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
          <LineChart
            :labels="BLN.map((_, i) => shortMonth(String(i + 1)))"
            :series="osSeries"
            :aria-label="`Grafik outstanding pembiayaan per kantor ${osTahun}`"
          />
          <p class="note">Garis = total semua produk per kantor. Rincian per produk di tabel.</p>
          <PbyTable :cols="osCols" :rows="os.rows" subtotal-by="kdloc" :subtotal-label="subLabel('nmcabang')" />
        </template>
      </section>
    </div>
  </div>
</template>
