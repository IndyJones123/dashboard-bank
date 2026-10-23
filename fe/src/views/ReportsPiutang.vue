<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, kantorColor, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import MoreDetails from './MoreDetails.vue'
import KantorPicker from './KantorPicker.vue'
import DetailTable, { type DetailCol } from './DetailTable.vue'

/* ==========================================================================
   LAPORAN PIUTANG: /api/laporan/piutang (Laporan-Keuangan-Piutang.sql)
   Tampilan DIAGRAM GARIS: 3 chart TERPISAH — Total Piutang + rincian per
   golongan akun (kolom golac TBLGL), masing-masing dgn tabel terperinci
   sendiri (paginated, 1 baris/kolom + gulir horizontal). WARNA = kantor.
   ========================================================================== */

interface PiutangRow {
  ket: string
  golac?: string
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
const rows = ref<PiutangRow[]>([])
const golacRows = ref<PiutangRow[]>([])
const loading = ref(true)
const error = ref('')
/** Tabel terperinci per chart disembunyikan default; dibuka via More details. */
const detOpen = ref<Record<string, boolean>>({})
const toggleDet = (id: string) => {
  detOpen.value[id] = !detOpen.value[id]
}
/** Kantor yang disembunyikan dari grafik & total (filter tampilan saja). */
const hidden = ref<string[]>([])

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

interface Pivot {
  id: string
  label: string
  cells: Record<string, number | null>
}

/** Pivot list row -> 1 baris per (grup × kantor) dengan kolom periode. */
function pivot(src: PiutangRow[], groupOf: (r: PiutangRow) => string, labelOf: (r: PiutangRow) => string): Pivot[] {
  const map = new Map<string, Pivot>()
  for (const r of src) {
    const id = `${groupOf(r)}|${r.kdloc}`
    let row = map.get(id)
    if (!row) {
      row = { id, label: labelOf(r), cells: {} }
      map.set(id, row)
    }
    row.cells[`${r.thn}-${r.bln}`] = r.saldo
  }
  return [...map.values()].sort((a, b) => a.label.localeCompare(b.label))
}

const kantors = computed(() =>
  [...new Set([...rows.value, ...golacRows.value].map((r) => r.kdloc))].sort(),
)
const shown = (r: PiutangRow): boolean => !hidden.value.includes(r.kdloc)
const mainPivot = computed(() =>
  pivot(rows.value.filter(shown), () => 'piutang', () => 'Piutang'),
)
const golacPivot = computed(() =>
  pivot(golacRows.value.filter(shown), (r) => `golac-${r.golac ?? '-'}`, (r) => `Golongan ${r.golac ?? '-'}`),
)
const kColor = (k: string): string => kantorColor(k, kantors.value)
const kLabel = (k: string): string => (k === '00' ? 'Semua Kantor' : `Kantor ${k}`)

/** 3 chart TERPISAH: Total Piutang + 1 per golongan akun. Id golongan DARI
    DATA (golac bisa berubah, jangan hardcode) — diurutkan, jadi selalu
    urutan Total, Golongan 1, Golongan 2, dst. */
const golIds = computed(() =>
  [...new Set(golacPivot.value.map((p) => p.id.split('|')[0]))].sort(),
)
const chartDefs = computed<{ id: string; label: string }[]>(() => [
  { id: 'piutang', label: 'Total Piutang' },
  ...golIds.value.map((id) => ({ id, label: `Golongan ${id.replace('golac-', '')}` })),
])

/** Garis per chart: 1 garis per kantor (warna = kantor; tanpa dash — chart sudah terpisah). */
const seriesOf = (chartId: string): LineSerie[] => {
  const all = [...mainPivot.value, ...golacPivot.value]
  return kantors.value.flatMap((k): LineSerie[] => {
    const row = all.find((p) => p.id === `${chartId}|${k}`)
    if (!row) return []
    return [
      {
        key: `${chartId}|${k}`,
        label: kLabel(k),
        color: kColor(k),
        values: periodKeys.value.map((p) => row.cells[p.key] ?? null),
      },
    ]
  })
}

/** Baris tabel terperinci per chart: 1 baris per kantor, kolom = periode
    (paginated DetailTable). Fungsi biasa (bukan computed) — dipanggil saat
    render, dependensi tetap ter-track. */
const tableRows = (chartId: string): Record<string, unknown>[] => {
  const src =
    chartId === 'piutang'
      ? mainPivot.value
      : golacPivot.value.filter((p) => p.id.startsWith(`${chartId}|`))
  return src.map((p) => {
    const [, k] = p.id.split('|')
    return {
      id: p.id,
      label: kLabel(k ?? '00'),
      ...Object.fromEntries(periodKeys.value.map((pr) => [pr.key, p.cells[pr.key] ?? null])),
    }
  })
}

/** Kolom tabel terperinci: Kantor + kolom periode (angka rata kanan). */
const tableCols = computed<DetailCol[]>(() => [
  { key: 'label', label: 'Kantor' },
  ...periodKeys.value.map((p) => ({ key: p.key, label: p.label, right: true })),
])

/** Satu entri per chart (defs + garis + baris tabel) utk loop template:
    Total Piutang, Golongan 1, Golongan 2 — masing-masing chart + tabel sendiri. */
const chartData = computed(() =>
  chartDefs.value.map((c) => ({ ...c, series: seriesOf(c.id), rows: tableRows(c.id) })),
)
const hasChart = computed(() => chartData.value.some((c) => c.series.length > 0))

/** Periode kartu: bulan TERAKHIR dgn data (saldo > 0; baris bln depan di
    snapshot parsial balik 0 — existence saja bikin kartu "Posisi Des" = 0
    dan pertumbuhan -100% padahal grafik ada isinya). */
const lastKey = computed<string>(
  () =>
    periodKeys.value
      .filter((p) => !p.carry && rows.value.some((r) => `${r.thn}-${r.bln}` === p.key && r.saldo > 0))
      .at(-1)?.key ?? `${tahun.value}-12`,
)
const lastLabel = computed(
  () => periodKeys.value.find((p) => p.key === lastKey.value)?.label ?? '',
)
const totalAkhir = computed(() =>
  mainPivot.value.reduce((s, p) => s + (p.cells[lastKey.value] ?? 0), 0),
)
const totalAwal = computed(() => {
  const key = `${Number(tahun.value) - 1}-12`
  return mainPivot.value.reduce((s, p) => s + (p.cells[key] ?? 0), 0)
})
const growthPct = computed<number | null>(() => {
  if (!totalAwal.value || !totalAkhir.value) return null
  return ((totalAkhir.value - totalAwal.value) / totalAwal.value) * 100
})
async function load(first = false): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    for (;;) {
      const { data } = await api.get<{ rows: PiutangRow[]; golac: PiutangRow[] }>('/api/laporan/piutang', {
        params: { tahun: tahun.value, kdloc: '00' },
      })
      rows.value = data.rows ?? []
      golacRows.value = data.golac ?? []
      const empty = !rows.value.length && !golacRows.value.length
      if (!first || !empty || Number(tahun.value) <= Number(TAHUN_MIN)) break
      tahun.value = String(Number(tahun.value) - 1)
    }
  } catch (e) {
    rows.value = []
    golacRows.value = []
    error.value = apiErrText(e, 'Gagal memuat laporan piutang. Pastikan BE jalan.')
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
        <span class="label">Posisi Piutang</span>
        <strong class="num">{{ loading ? '–' : formatRupiah(totalAkhir) }}</strong>
        <span class="muted small">{{ lastLabel }}</span>
      </div>
      <div class="card metric">
        <span class="label">Pertumbuhan Piutang</span>
        <strong class="num">
          {{ loading ? '–' : (growthPct == null ? '–' : `${growthPct >= 0 ? '+' : ''}${growthPct.toFixed(1)}%`) }}
        </strong>
        <span v-if="growthPct != null" :class="['chip', growthPct >= 0 ? 'up' : 'down']">
          <i class="dot" aria-hidden="true" />Des {{ Number(tahun) - 1 }} s.d. Des {{ tahun }}
        </span>
        <span v-else class="muted small">Tidak ada pembanding Des {{ Number(tahun) - 1 }}</span>
      </div>
      <div class="card metric">
        <span class="label">Selisih vs Des {{ Number(tahun) - 1 }}</span>
        <strong class="num">{{ loading ? '–' : formatRupiah(totalAkhir - totalAwal) }}</strong>
        <span :class="['chip', (totalAkhir - totalAwal) >= 0 ? 'up' : 'down']">
          <i class="dot" aria-hidden="true" />Des {{ Number(tahun) - 1 }} s.d. {{ lastLabel }}
        </span>
      </div>
    </section>

    <section class="panel">
      <h2>Laporan Piutang: {{ tahun }}</h2>
      <p class="sub">
        Satu diagram per golongan (Total Piutang, Golongan 1, Golongan 2) · warna = kantor{{ kantors.length > 1 ? ` (${kantors.length} kantor)` : '' }}
      </p>
      <p v-if="loading" class="muted">Memuat laporan piutang…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else-if="!hasChart" class="muted">Belum ada data untuk filter ini. Coba ganti tahun atau kantor.</p>
      <template v-else>
        <div v-for="c in chartData" :key="c.id" class="chart-block">
          <h3 class="chart-title">{{ c.label }}</h3>
          <LineChart
            :labels="periodKeys.map((p) => p.label)"
            :series="c.series"
            :aria-label="`Grafik garis ${c.label} per kantor`"
          />
          <p class="note">
            Hover titik utk nilai rupiah · warna = kantor ·
            titik pertama (Des sebelumnya) = carry-over saldo awal tahun.
          </p>
          <MoreDetails :id="`det-${c.id}`" :open="!!detOpen[c.id]" @toggle="toggleDet(c.id)">
            <DetailTable :cols="tableCols" :rows="tableRows(c.id)" :per-page="10" />
          </MoreDetails>
        </div>
      </template>
    </section>
  </div>
</template>

<style scoped>
/* Pemisah antar chart golongan (Total, Golongan 1, Golongan 2). */
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

