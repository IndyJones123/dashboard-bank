<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api from '../api'
import { apiErrText, kantorColor, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import MoreDetails from './MoreDetails.vue'
import KantorPicker from './KantorPicker.vue'
import DetailTable, { type DetailCol } from './DetailTable.vue'
import Sparkline from './Sparkline.vue'
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'
import RpValue from './RpValue.vue'

// Layout widget dari CMS; tiap grafik produk = 1 widget (grafik-tabungan, grafik-deposito)
const w = useWidgets('reports-dpk')
const chartWidget = (short: string): string => `grafik-${short.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`

/* ==========================================================================
   LAPORAN DPK: /api/laporan/dpk (Laporan-Keuangan-DPK.sql)
   Tampilan DIAGRAM GARIS: 2 chart TERPISAH: DPK Tabungan & DPK Deposito
   (jangan digabung), masing-masing dgn tabel terperinci sendiri (paginated,
   1 baris/kolom + gulir horizontal). WARNA = kantor.
   Kunci sel: ket|kdloc|thn-bln.
   ========================================================================== */

interface DpkRow {
  ket: string
  kdloc: string
  thn: string
  bln: string
  saldo: number
}

const tahun = ref(String(new Date().getFullYear() - 1))
/** Opsi tahun = 5 thn ke belakang; BE bisa belum punya data thn terbaru
    (DB berhenti s.d. 2024). Saat muat PERTAMA kali mundur 1 thn s.d. ketemu
    data (min. opsi ter tua) supaya grafik + tabel detail langsung tampil;
    pilihan tahun user setelah itu dihormati (tanpa fallback). */
const TAHUN_MIN = String(new Date().getFullYear() - 4)
const rows = ref<DpkRow[]>([])
const loading = ref(true)
const error = ref('')
/** Tabel terperinci per chart disembunyikan default; dibuka via More details. */
const detOpen = ref<Record<string, boolean>>({})
const toggleDet = (id: string) => {
  detOpen.value[id] = !detOpen.value[id]
}
/** Kantor yang disembunyikan dari grafik & total (filter tampilan saja). */
const hidden = ref<string[]>([])

/** ['12' (Des thn lalu), '01'..'12'], urutan periode sumbu X. */
const periodKeys = computed(() => {
  const prev = String(Number(tahun.value) - 1)
  return [
    { key: `${prev}-12`, label: `Des ${prev}`, carry: true },
    ...Array.from({ length: 12 }, (_, i) => ({
      key: `${tahun.value}-${String(i + 1).padStart(2, '0')}`,
      label: `${shortMonth(String(i + 1))} ${tahun.value}`,
      carry: false,
    })),
  ]
})

/** cellKey = ket|kdloc|thn-bln -> saldo (pivot sekali utk lookup O(1)). Kantor tersembunyi dikecualikan. */
const cells = computed(() => {
  const m = new Map<string, number>()
  for (const r of rows.value) {
    if (hidden.value.includes(r.kdloc)) continue
    m.set(`${r.ket}|${r.kdloc}|${r.thn}-${r.bln}`, r.saldo)
  }
  return m
})

const KET_ORDER = ['DPK Tabungan', 'DPK Deposito']
const kantors = computed(() => [...new Set(rows.value.map((r) => r.kdloc))].sort())
const visibleKantors = computed(() => kantors.value.filter((k) => !hidden.value.includes(k)))
const kets = computed(() => {
  const seen = [...new Set(rows.value.map((r) => r.ket))]
  return seen.sort(
    (a, b) =>
      (KET_ORDER.indexOf(a) + 99 || 0) - (KET_ORDER.indexOf(b) + 99 || 0) || a.localeCompare(b),
  )
})

const kColor = (k: string): string => kantorColor(k, kantors.value)
const kLabel = (k: string): string => (k === '00' ? 'Semua Kantor' : `Kantor ${k}`)

const val = (ket: string, k: string, key: string): number | null =>
  cells.value.get(`${ket}|${k}|${key}`) ?? null

const hasData = computed(() => cells.value.size > 0)

/** Kolom tabel terperinci per chart: Kantor + kolom periode (angka rata kanan). */
const tableCols = computed<DetailCol[]>(() => [
  { key: 'label', label: 'Kantor' },
  ...periodKeys.value.map((p) => ({ key: p.key, label: p.label, right: true })),
])

/** Satu entri chart per produk (Tabungan, Deposito): TIDAK digabung jadi 1 chart. */
const charts = computed<{ ket: string; id: string; short: string; series: LineSerie[] }[]>(
  () =>
    kets.value.map((ket) => ({
      ket,
      id: `dpk-${ket.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
      short: ket.replace(/^DPK\s+/i, ''),
      series: visibleKantors.value.map((k) => ({
        key: `${ket}|${k}`,
        label: kLabel(k),
        color: kColor(k),
        values: periodKeys.value.map((p) => val(ket, k, p.key)),
      })),
    })),
)

/** Baris tabel per chart: 1 baris per kantor, kolom = periode (paginated DetailTable).
    Fungsi biasa (bukan computed): dipanggil saat render, dependensi tetap ter-track. */
const tableRows = (ket: string) =>
  visibleKantors.value.map((k) => ({
    id: k,
    label: kLabel(k),
    ...Object.fromEntries(periodKeys.value.map((p) => [p.key, val(ket, k, p.key)])),
  }))

/** Bulan & label terakhir dgn data (DB bisa parsial, mis. 2024 s.d. Mei) :
    kartu tidak boleh 0 padahal grafik ada isinya. 'Punya data' = saldo > 0:
    baris bln depan di snapshot parsial balik saldo 0: existence saja bikin
    kartu lompat ke Des berisi Rp 0. */
const lastBln = computed<string>(
  () =>
    periodKeys.value
      .filter(
        (p) => !p.carry && rows.value.some((r) => `${r.thn}-${r.bln}` === p.key && r.saldo > 0),
      )
      .at(-1)?.key.split('-')[1] ?? '12',
)
const lastLabel = computed(
  () =>
    periodKeys.value.find((p) => p.key === `${tahun.value}-${lastBln.value}`)?.label ??
    `Des ${tahun.value}`,
)
/** Total saldo bulan terakhir dgn data (opsional per produk), bahan kartu metrik. */
const sumDes = (ket?: string): number =>
  rows.value.reduce(
    (s, r) =>
      (r.thn === tahun.value && r.bln === lastBln.value && !hidden.value.includes(r.kdloc) && (!ket || r.ket === ket) ? s + r.saldo : s),
    0,
  )
const pctOf = (ket: string): string => {
  const total = sumDes()
  return total ? `${((sumDes(ket) / total) * 100).toFixed(1)}% dari total DPK` : '–'
}
/** Deret konsolidasi per periode utk sparkline kartu: JUMLAH saldo semua
    kantor terlihat per periode: baris = sumber sama dgn kartu/grafik
    (tanpa angka rekaan); periode tanpa baris = null (garis terputus). */
const sumSeries = (ket?: string): (number | null)[] =>
  periodKeys.value.map((p) => {
    let s = 0
    let n = 0
    for (const r of rows.value) {
      if (hidden.value.includes(r.kdloc)) continue
      if (ket && r.ket !== ket) continue
      if (`${r.thn}-${r.bln}` !== p.key) continue
      s += r.saldo
      n += 1
    }
    return n ? s : null
  })

async function load(first = false): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    for (;;) {
      const { data } = await api.get<{ rows: DpkRow[] }>('/api/laporan/dpk', {
        params: { tahun: tahun.value, kdloc: '00' },
      })
      rows.value = data.rows ?? []
      if (!first || rows.value.length || Number(tahun.value) <= Number(TAHUN_MIN)) break
      tahun.value = String(Number(tahun.value) - 1)
    }
  } catch (e) {
    rows.value = []
    error.value = apiErrText(e, 'Gagal memuat laporan DPK. Pastikan BE jalan.')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void load(true)
})
</script>

<template>
  <div>
    <div class="toolbar report-filters">
      <div class="filters">
        <label>
          Tahun
          <select v-model="tahun" @change="load()">
            <option v-for="y in Array.from({ length: 5 }, (_, i) => String(new Date().getFullYear() - i))" :key="y" :value="y">
              {{ y }}
            </option>
          </select>
        </label>
        <KantorPicker v-if="!loading && !error" v-model="hidden" :kantors="kantors" />
      </div>
      <span v-if="loading" class="muted small">Memuat laporan…</span>
    </div>

    <WidgetNotice :w="w" />
    <div class="wgrid">
    <section v-if="w.show('angka-utama')" class="w lead-part hero" :style="w.style('angka-utama')">
        <p class="lead-label">DPK Tabungan + Deposito</p>
        <p class="lead-value num"><RpValue :value="loading ? null : sumDes()" /></p>
        <p class="lead-note">Posisi {{ lastLabel }}, {{ kantors.length }} kantor</p>
    </section>
    <section v-if="w.show('ringkasan')" class="w lead-part" :style="w.style('ringkasan')">
        <div class="lead-spark">
          <Sparkline v-if="!loading" :values="sumSeries()" aria-label="Tren total DPK per bulan" />
        </div>
        <dl class="ledger">
          <div>
            <dt>DPK Tabungan <small>{{ loading ? '–' : pctOf('DPK Tabungan') }}</small></dt>
            <span class="ledger-spark">
              <Sparkline v-if="!loading" :values="sumSeries('DPK Tabungan')" aria-label="Tren DPK Tabungan per bulan" />
            </span>
            <dd class="num"><RpValue :value="loading ? null : sumDes('DPK Tabungan')" /></dd>
          </div>
          <div>
            <dt>DPK Deposito <small>{{ loading ? '–' : pctOf('DPK Deposito') }}</small></dt>
            <span class="ledger-spark">
              <Sparkline v-if="!loading" :values="sumSeries('DPK Deposito')" aria-label="Tren DPK Deposito per bulan" />
            </span>
            <dd class="num"><RpValue :value="loading ? null : sumDes('DPK Deposito')" /></dd>
          </div>
        </dl>
    </section>

    <!-- Status muat/galat/kosong: satu panel di posisi widget grafik pertama -->
    <section
      v-if="(loading || error || !hasData) && (w.show('grafik-tabungan') || w.show('grafik-deposito'))"
      class="w panel"
      :style="w.style(w.show('grafik-tabungan') ? 'grafik-tabungan' : 'grafik-deposito')"
    >
      <h2>Tren {{ tahun }}</h2>
      <p v-if="loading" class="muted">Memuat laporan DPK…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else class="muted">Belum ada data untuk filter ini. Coba ganti tahun atau kantor.</p>
    </section>
    <template v-else-if="!loading && !error && hasData">
      <template v-for="c in charts" :key="c.ket">
        <section v-if="w.show(chartWidget(c.short))" class="w panel" :style="w.style(chartWidget(c.short))">
          <h2>DPK {{ c.short }}</h2>
          <p class="sub">Tren {{ tahun }}. Warna menandai kantor{{ kantors.length > 1 ? ` (${kantors.length} kantor)` : '' }}.</p>
          <LineChart
            :labels="periodKeys.map((p) => p.label)"
            :series="c.series"
            :aria-label="`Grafik garis DPK ${c.short.toLowerCase()} per kantor`"
          />
          <p class="note">
            Arahkan kursor ke titik untuk nilai rupiah penuh. Titik pertama
            (Des tahun sebelumnya) adalah saldo awal tahun.
          </p>
          <MoreDetails :id="`det-${c.id}`" :open="!!detOpen[c.id]" @toggle="toggleDet(c.id)">
            <DetailTable :cols="tableCols" :rows="tableRows(c.ket)" :per-page="10" />
          </MoreDetails>
        </section>
      </template>
    </template>
    </div>
  </div>
</template>

