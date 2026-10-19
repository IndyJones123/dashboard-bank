<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, formatRpSingkat, kantorColor, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import MoreDetails from './MoreDetails.vue'

/* ==========================================================================
   LAPORAN PIUTANG: /api/laporan/piutang (Laporan-Keuangan-Piutang.sql)
   Tampilan DIAGRAM GARIS (bukan tabel), 1 chart: total piutang + rincian
   per golongan akun (kolom golac TBLGL). WARNA = kantor, dash = golongan.
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
const kdloc = ref('00')
const offices = ref<string[]>(['00'])
const rows = ref<PiutangRow[]>([])
const golacRows = ref<PiutangRow[]>([])
const loading = ref(true)
const error = ref('')
/** Tabel terperinci default tersembunyi; dibuka via tombol More details. */
const detOpen = ref(false)

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

const mainPivot = computed(() =>
  pivot(rows.value, () => 'piutang', () => 'Piutang'),
)
const golacPivot = computed(() =>
  pivot(golacRows.value, (r) => `golac-${r.golac ?? '-'}`, (r) => `Golongan ${r.golac ?? '-'}`),
)
const kantors = computed(() =>
  [...new Set([...rows.value, ...golacRows.value].map((r) => r.kdloc))].sort(),
)
const kColor = (k: string): string => kantorColor(k, kantors.value)
const kLabel = (k: string): string => (k === '00' ? 'Semua Kantor' : `Kantor ${k}`)

/** Garis: solid = total, dash = golongan. Id golongan DARI DATA (golac bisa
    berubah, contoh sekarang golongan 1 + 6) — jangan hardcode. */
const GROUPS = computed(() => [
  { id: 'piutang', label: 'Total Piutang', dash: undefined as string | undefined },
  ...[...new Set(golacPivot.value.map((p) => p.id.split('|')[0]))]
    .sort()
    .map(
      (id, i): { id: string; label: string; dash: string } => ({
        id,
        label: `Golongan ${id.replace('golac-', '')}`,
        dash: ['7 5', '2 4'][i % 2],
      }),
    ),
])

const series = computed<LineSerie[]>(() => {
  const all = [...mainPivot.value, ...golacPivot.value]
  return kantors.value.flatMap((k) =>
    GROUPS.value.map((g): LineSerie | null => {
      const row = all.find((p) => p.id === `${g.id}|${k}`)
      if (!row) return null
      return {
        key: `${g.id}|${k}`,
        label: `${kLabel(k)} · ${g.label}`,
        color: kColor(k),
        dash: g.dash,
        values: periodKeys.value.map((p) => row.cells[p.key] ?? null),
      }
    }),
  ).filter((s): s is LineSerie => s != null)
})

/** Periode kartu: bulan TERAKHIR dgn data di tahun terpilih (DB bisa parsial,
    mis. 2024 s.d. Mei) — Des hanya bila tahun penuh. Tanpa ini kartu "Posisi
    Des 2024" = 0 dan pertumbuhan jadi -100% padahal grafik ada isinya. */
const lastKey = computed<string>(
  () =>
    periodKeys.value
      .filter((p) => !p.carry && rows.value.some((r) => `${r.thn}-${r.bln}` === p.key))
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
/** Baris tabel terperinci: 1 baris per (grup akun × kantor) × kolom periode. */
const detailRows = computed(() =>
  [...mainPivot.value, ...golacPivot.value].map((p) => {
    const [, k] = p.id.split('|')
    return {
      id: p.id,
      label: p.label,
      kLabel: kLabel(k ?? '00'),
      cells: periodKeys.value.map((pr) => p.cells[pr.key] ?? null),
    }
  }),
)

async function loadOffices(): Promise<void> {
  try {
    const { data } = await api.get<{ kdloc: string }[]>('/api/gl/offices')
    offices.value = ['00', ...data.map((o) => String(o.kdloc))]
  } catch {
    offices.value = ['00']
  }
}

async function load(first = false): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    for (;;) {
      const { data } = await api.get<{ rows: PiutangRow[]; golac: PiutangRow[] }>('/api/laporan/piutang', {
        params: { tahun: tahun.value, kdloc: kdloc.value },
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
  void loadOffices()
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
          <label>
            Kantor
            <select v-model="kdloc" @change="load()">
              <option value="00">Semua Kantor</option>
              <option v-for="o in offices.filter((v) => v !== '00')" :key="o" :value="o">Kantor {{ o }}</option>
            </select>
          </label>
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
        Total &amp; per golongan akun dalam satu diagram · warna = kantor{{ kantors.length > 1 ? ` (${kantors.length} kantor)` : '' }}
      </p>
      <p v-if="loading" class="muted">Memuat laporan piutang…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else-if="!series.length" class="muted">Belum ada data untuk filter ini. Coba ganti tahun atau kantor.</p>
      <template v-else>
        <LineChart
          :labels="periodKeys.map((p) => p.label)"
          :series="series"
          aria-label="Grafik garis piutang total dan per golongan akun"
        />
        <p class="muted small note">
          Hover titik utk nilai rupiah · garis solid = total, dash = golongan ·
          titik pertama (Des sebelumnya) = carry-over saldo awal tahun.
        </p>
        <MoreDetails id="det-piutang" :open="detOpen" @toggle="detOpen = !detOpen">
          <div class="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Golongan</th>
                  <th>Kantor</th>
                  <th v-for="p in periodKeys" :key="p.key" class="ta-r">{{ p.label }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="d in detailRows" :key="d.id">
                  <td>{{ d.label }}</td>
                  <td>{{ d.kLabel }}</td>
                  <td v-for="(c, i) in d.cells" :key="i" class="ta-r num"
                      :title="c == null ? undefined : formatRupiah(c)">{{ c == null ? '–' : formatRpSingkat(c) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </MoreDetails>
      </template>
    </section>
  </div>
</template>

<style scoped>
.note {
  margin-top: 0.75rem;
}
</style>
