<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, formatRpSingkat, kantorColor, shortMonth } from '../report-helpers'
import LineChart, { type LineSerie } from './LineChart.vue'
import MoreDetails from './MoreDetails.vue'

/* ==========================================================================
   LAPORAN DPK: /api/laporan/dpk (Laporan-Keuangan-DPK.sql)
   Tampilan DIAGRAM GARIS (bukan tabel): 1 chart berisi DPK Tabungan + DPK
   Deposito. WARNA = kantor (kalau >1 kantor), garis putus-putus = Deposito.
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
const kdloc = ref('00')
const offices = ref<string[]>(['00'])
const rows = ref<DpkRow[]>([])
const loading = ref(true)
const error = ref('')
/** Tabel terperinci default tersembunyi; dibuka via tombol More details. */
const detOpen = ref(false)

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

/** cellKey = ket|kdloc|thn-bln -> saldo (pivot sekali utk lookup O(1)). */
const cells = computed(() => {
  const m = new Map<string, number>()
  for (const r of rows.value) m.set(`${r.ket}|${r.kdloc}|${r.thn}-${r.bln}`, r.saldo)
  return m
})

const KET_ORDER = ['DPK Tabungan', 'DPK Deposito']
const kantors = computed(() => [...new Set(rows.value.map((r) => r.kdloc))].sort())
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

/** Baris tabel terperinci: 1 baris per (kantor × produk) × kolom periode. */
const detailRows = computed(() =>
  kantors.value.flatMap((k) =>
    kets.value.map((ket) => ({
      id: `${k}|${ket}`,
      label: kLabel(k),
      ket,
      cells: periodKeys.value.map((p) => val(ket, k, p.key)),
    })),
  ),
)

const hasData = computed(() => cells.value.size > 0)

/** 1 garis per (kantor × produk): warna = kantor, dash = Deposito. */
const series = computed<LineSerie[]>(() =>
  kantors.value.flatMap((k) =>
    kets.value.map((ket) => ({
      key: `${ket}|${k}`,
      label: `${kLabel(k)} · ${ket.replace(/^DPK\s+/i, '')}`,
      color: kColor(k),
      dash: /depos/i.test(ket) ? '7 5' : undefined,
      values: periodKeys.value.map((p) => val(ket, k, p.key)),
    })),
  ),
)

/** Bulan & label terakhir dgn data di tahun terpilih (DB bisa parsial,
    mis. 2024 s.d. Mei) — kartu tidak boleh 0 padahal grafik ada isinya. */
const lastBln = computed<string>(
  () =>
    periodKeys.value
      .filter((p) => !p.carry && rows.value.some((r) => `${r.thn}-${r.bln}` === p.key))
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
      (r.thn === tahun.value && r.bln === lastBln.value && (!ket || r.ket === ket) ? s + r.saldo : s),
    0,
  )
const pctOf = (ket: string): string => {
  const total = sumDes()
  return total ? `${((sumDes(ket) / total) * 100).toFixed(1)}% dari total DPK` : '–'
}

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
      const { data } = await api.get<{ rows: DpkRow[] }>('/api/laporan/dpk', {
        params: { tahun: tahun.value, kdloc: kdloc.value },
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
        DPK Tabungan &amp; Deposito dalam satu diagram · warna = kantor{{ kantors.length > 1 ? ` (${kantors.length} kantor)` : '' }}
      </p>
      <p v-if="loading" class="muted">Memuat laporan DPK…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else-if="!hasData" class="muted">Belum ada data untuk filter ini. Coba ganti tahun atau kantor.</p>
      <template v-else>
        <LineChart
          :labels="periodKeys.map((p) => p.label)"
          :series="series"
          aria-label="Grafik garis DPK tabungan dan deposito per kantor"
        />
        <p class="muted small note">
          Hover titik utk nilai rupiah · warna = kantor, garis putus-putus = DPK Deposito ·
          titik pertama (Des sebelumnya) = carry-over saldo awal tahun.
        </p>
        <MoreDetails id="det-dpk" :open="detOpen" @toggle="detOpen = !detOpen">
          <div class="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Kantor</th>
                  <th>Uraian</th>
                  <th v-for="p in periodKeys" :key="p.key" class="ta-r">{{ p.label }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="d in detailRows" :key="d.id">
                  <td>{{ d.label }}</td>
                  <td>{{ d.ket }}</td>
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
