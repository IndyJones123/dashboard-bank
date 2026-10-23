<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, kantorColor, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import MoreDetails from './MoreDetails.vue'
import KantorPicker from './KantorPicker.vue'
import DetailTable, { type DetailCol } from './DetailTable.vue'

/* ==========================================================================
   LAPORAN DPK: /api/laporan/dpk (Laporan-Keuangan-DPK.sql)
   Tampilan DIAGRAM GARIS: 2 chart TERPISAH — DPK Tabungan & DPK Deposito
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

/** Satu entri chart per produk (Tabungan, Deposito) — TIDAK digabung jadi 1 chart. */
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
    Fungsi biasa (bukan computed) — dipanggil saat render, dependensi tetap ter-track. */
const tableRows = (ket: string) =>
  visibleKantors.value.map((k) => ({
    id: k,
    label: kLabel(k),
    ...Object.fromEntries(periodKeys.value.map((p) => [p.key, val(ket, k, p.key)])),
  }))

/** Bulan & label terakhir dgn data (DB bisa parsial, mis. 2024 s.d. Mei) —
    kartu tidak boleh 0 padahal grafik ada isinya. 'Punya data' = saldo > 0:
    baris bln depan di snapshot parsial balik saldo 0 — existence saja bikin
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
    <section class="panel">
      <div class="toolbar">
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
        <span v-if="loading" class="muted small">Memuat…</span>
      </div>
    </section>

    <section class="cards">
      <div class="card metric">
        <span class="label">DPK Tabungan + Deposito</span>
        <strong class="num">{{ loading ? '–' : formatRupiah(sumDes()) }}</strong>
        <span class="muted small">Posisi {{ lastLabel }} · {{ kantors.length }} kantor</span>
      </div>
      <div class="card metric">
        <span class="label">DPK Tabungan</span>
        <strong class="num">{{ loading ? '–' : formatRupiah(sumDes('DPK Tabungan')) }}</strong>
        <span class="muted small">{{ loading ? '–' : pctOf('DPK Tabungan') }}</span>
      </div>
      <div class="card metric">
        <span class="label">DPK Deposito</span>
        <strong class="num">{{ loading ? '–' : formatRupiah(sumDes('DPK Deposito')) }}</strong>
        <span class="muted small">{{ loading ? '–' : pctOf('DPK Deposito') }}</span>
      </div>
    </section>

    <section class="panel">
      <h2>Laporan DPK: {{ tahun }}</h2>
      <p class="sub">
        Satu diagram per produk (Tabungan &amp; Deposito terpisah) · warna = kantor{{ kantors.length > 1 ? ` (${kantors.length} kantor)` : '' }}
      </p>
      <p v-if="loading" class="muted">Memuat laporan DPK…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else-if="!hasData" class="muted">Belum ada data untuk filter ini. Coba ganti tahun atau kantor.</p>
      <template v-else>
        <div v-for="c in charts" :key="c.ket" class="chart-block">
          <h3 class="chart-title">DPK {{ c.short }}</h3>
          <LineChart
            :labels="periodKeys.map((p) => p.label)"
            :series="c.series"
            :aria-label="`Grafik garis DPK ${c.short.toLowerCase()} per kantor`"
          />
          <p class="note">
            Hover titik utk nilai rupiah · warna = kantor ·
            titik pertama (Des sebelumnya) = carry-over saldo awal tahun.
          </p>
          <MoreDetails :id="`det-${c.id}`" :open="!!detOpen[c.id]" @toggle="toggleDet(c.id)">
            <DetailTable :cols="tableCols" :rows="tableRows(c.ket)" :per-page="10" />
          </MoreDetails>
        </div>
      </template>
    </section>
  </div>
</template>

<style scoped>
/* Pemisah antar chart produk (Tabungan vs Deposito). */
.chart-block + .chart-block {
  margin-top: 1.6rem;
  padding-top: 1.2rem;
  border-top: 1px dashed var(--border);
}
.chart-title {
  font-family: var(--font-display);
  font-size: 0.98rem;
  color: var(--primary);
  margin: 0 0 0.45rem;
}
</style>

