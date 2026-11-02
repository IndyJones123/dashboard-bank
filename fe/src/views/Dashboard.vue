<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import api, { formatRupiah } from '../api'
import { isLoggedIn } from '../stores/auth'

interface Stats {
  total_nasabah: number
  total_simpanan: number
  transaksi_hari_ini: number
  kredit_berjalan: number
}
interface Flow {
  bulan: string
  setor: number
  tarik: number
}
interface Tx {
  id: number
  tanggal: string
  jenis: string
  nominal: number
  berita: string
  no_rekening: string
  nasabah: string
}
interface TopDeposit {
  nama: string
  kota: string
  jumlah_rekening: number
  total_saldo: number
}
interface Profit {
  bulan: string
  laba: number
}

const router = useRouter()
const stats = ref<Stats | null>(null)
const flow = ref<Flow[]>([])
const recent = ref<Tx[]>([])
const topDeposits = ref<TopDeposit[]>([])
const profit = ref<Profit[]>([])
const loading = ref(true)
const loadingPremium = ref(false)
const error = ref('')

const maxFlow = computed(() => Math.max(1, ...flow.value.flatMap((f) => [f.setor, f.tarik])))

// Label nilai di atas tiap batang: M = miliar, Jt = juta; negatif = rugi
function fmtFlow(v: number): string {
  const s = Math.abs(v)
  const unit = s >= 1e9 ? 'M' : s >= 1e6 ? 'Jt' : s >= 1e3 ? 'rb' : ''
  const n =
    s >= 1e9 ? (s / 1e9).toLocaleString('id-ID', { maximumFractionDigits: 1 })
    : s >= 1e6 ? (s / 1e6).toLocaleString('id-ID', { maximumFractionDigits: 1 })
    : s >= 1e3 ? String(Math.round(s / 1e3))
    : String(Math.round(s))
  return `${v < 0 ? '-' : ''}${n}${unit}`
}

function shortMonth(bulan: string): string {
  const m = bulan.slice(5)
  const names: Record<string, string> = {
    '01': 'Jan', '02': 'Feb', '03': 'Mar', '04': 'Apr', '05': 'Mei', '06': 'Jun',
    '07': 'Jul', '08': 'Agu', '09': 'Sep', '10': 'Okt', '11': 'Nov', '12': 'Des',
  }
  return names[m] ?? m
}

// Perubahan setor bulan terakhir vs sebelumnya (data asli, bukan rekaan)
const setorDelta = computed(() => {
  if (flow.value.length < 2) return null
  const a = flow.value[flow.value.length - 2].setor
  const b = flow.value[flow.value.length - 1].setor
  if (!a) return null
  return ((b - a) / a) * 100
})

// Donat komposisi: total setor vs tarik 6 bulan (data asli)
const donut = computed(() => {
  const setor = flow.value.reduce((s, f) => s + f.setor, 0)
  const tarik = flow.value.reduce((s, f) => s + f.tarik, 0)
  const total = setor + tarik || 1
  return { setor, tarik, setorPct: (setor / total) * 100, tarikPct: (tarik / total) * 100 }
})

// Segmen donat SVG (lingkaran r=44, keliling ≈ 276.46)
const donutSegs = computed(() => {
  const C = 2 * Math.PI * 44
  const s = (donut.value.setorPct / 100) * C
  return { C, setorLen: s, tarikLen: C - s, tarikOff: -s }
})

// Geometri per batang: x kanan-kiri + y kepala batang, tempat teks nilai
const flowBars = computed(() =>
  flow.value.map((f, i) => ({
    bulan: f.bulan,
    label: shortMonth(f.bulan),
    setor: f.setor,
    tarik: f.tarik,
    xSetor: 64 + i * 76,
    xTarik: 92 + i * 76,
    ySetor: 160 - Math.max(3, (f.setor / maxFlow.value) * 120),
    yTarik: 160 - Math.max(3, (f.tarik / maxFlow.value) * 120),
    vSetor: fmtFlow(f.setor),
    vTarik: fmtFlow(f.tarik),
  })),
)

// Diagram batang laba/rugi per bulan: laba = setor − tarik (BE),
// negatif = rugi (batang di bawah garis nol, label tetap di atas batang)
const labaBars = computed(() => {
  const rows = profit.value
  if (!rows.length) return null
  const vals = rows.map((r) => r.laba)
  const yMax = Math.max(0, ...vals)
  const yMin = Math.min(0, ...vals)
  const range = yMax - yMin || 1
  const yZero = 150 - ((0 - yMin) / range) * 126
  const step = 300 / rows.length
  return {
    yZero,
    rows: rows.map((r, i) => {
      const yv = 150 - ((r.laba - yMin) / range) * 126
      const cx = step * (i + 0.5)
      const neg = r.laba < 0
      return {
        bulan: r.bulan, label: shortMonth(r.bulan), val: r.laba,
        cx, x: cx - Math.min(22, step / 2 - 4), w: Math.min(44, step - 8),
        ry: Math.min(yv, yZero), h: Math.max(2, Math.abs(yZero - yv)),
        labelY: (neg ? yZero : yv) - 4, lab: fmtFlow(r.laba), neg,
      }
    }),
  }
})

async function loadPublic(): Promise<void> {
  const [s, f, r] = await Promise.all([
    api.get('/api/dashboard/stats'),
    api.get('/api/dashboard/monthly-flow'),
    api.get('/api/dashboard/recent-transactions', { params: { limit: 6 } }),
  ])
  stats.value = s.data
  flow.value = f.data
  recent.value = r.data
}

async function loadPremium(): Promise<void> {
  if (!isLoggedIn.value) return
  loadingPremium.value = true
  try {
    const [dep, prof] = await Promise.all([
      api.get('/api/dashboard/top-deposits', { params: { limit: 3 } }),
      api.get('/api/dashboard/monthly-profit'),
    ])
    topDeposits.value = dep.data
    profit.value = prof.data
  } catch {
    topDeposits.value = []
    profit.value = []
  } finally {
    loadingPremium.value = false
  }
}

onMounted(async () => {
  try {
    await loadPublic()
    await loadPremium()
  } catch {
    error.value = 'Gagal memuat dashboard. Pastikan BE jalan di http://localhost:8000'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div>
    <div class="page-head">
      <div>
        <h1>Dashboard</h1>
        <p>Ringkasan kinerja bank, diperbarui harian.</p>
      </div>
    </div>

    <p v-if="error" class="alert">{{ error }}</p>
    <p v-if="loading" class="muted">Memuat ringkasan dashboard…</p>

    <!-- Angka utama: Total Simpanan jadi fokus, 3 angka lain sebagai rincian -->
    <section v-if="stats" class="lead">
      <div>
        <p class="lead-label">Total Simpanan</p>
        <p class="lead-value num">{{ formatRupiah(stats.total_simpanan) }}</p>
        <p class="lead-note">Akumulasi seluruh rekening</p>
      </div>
      <dl class="ledger">
        <div>
          <dt>Total Nasabah <small>Terdaftar aktif</small></dt>
          <dd class="num">{{ stats.total_nasabah?.toLocaleString('id-ID') ?? '–' }}</dd>
        </div>
        <div>
          <dt>Transaksi Hari Ini <small>Setor dan tarik</small></dt>
          <dd class="num">{{ stats.transaksi_hari_ini?.toLocaleString('id-ID') ?? '–' }}</dd>
        </div>
        <div>
          <dt>Kredit Berjalan <small>Sisa pokok</small></dt>
          <dd class="num">{{ formatRupiah(stats.kredit_berjalan) }}</dd>
        </div>
      </dl>
    </section>

    <div class="dash-grid">
      <section class="panel span-8">
        <h2>Arus Kas 6 Bulan Terakhir</h2>
        <p class="sub">
          Setor dan tarik per bulan.
          <span v-if="setorDelta !== null" :class="['delta', setorDelta >= 0 ? 'up' : 'down']">
            Setor {{ setorDelta >= 0 ? '▲' : '▼' }} {{ Math.abs(setorDelta).toFixed(1) }}% dari bulan lalu
          </span>
        </p>
        <template v-if="flow.length">
        <div class="chart-wrap">
          <svg viewBox="0 18 560 164" role="img" aria-label="Grafik arus kas">
            <g v-for="g in [0, 1, 2, 3, 4]" :key="g">
              <line class="l-grid" x1="44" :y1="40 + g * 30" x2="550" :y2="40 + g * 30" />
              <text class="t-axis" x="38" :y="44 + g * 30" text-anchor="end" font-size="10">
                {{ (maxFlow * (4 - g) / 4 / 1e9).toFixed(0) }}M
              </text>
            </g>
            <g v-for="(b, bi) in flowBars" :key="b.bulan" :style="{ '--i': bi }">
              <rect
                class="svg-bar s1"
                :x="b.xSetor" :width="26"
                :y="b.ySetor" :height="160 - b.ySetor"
                rx="3"
              >
                <title>Setor {{ b.bulan }}: {{ formatRupiah(b.setor) }}</title>
              </rect>
              <rect
                class="svg-bar s2"
                :x="b.xTarik" :width="26"
                :y="b.yTarik" :height="160 - b.yTarik"
                rx="3"
              >
                <title>Tarik {{ b.bulan }}: {{ formatRupiah(b.tarik) }}</title>
              </rect>
              <!-- Nilai terlihat di atas tiap batang (tanpa hover) -->
              <text class="svg-bar-val t-val" :x="b.xSetor + 13" :y="b.ySetor - 5" text-anchor="middle" font-size="8.5">{{ b.vSetor }}</text>
              <text class="svg-bar-val t-val" :x="b.xTarik + 13" :y="b.yTarik - 5" text-anchor="middle" font-size="8.5">{{ b.vTarik }}</text>
              <text class="svg-bar-x t-axis" :x="b.xSetor + 27" y="175" text-anchor="middle" font-size="10">
                {{ b.label }}
              </text>
            </g>
          </svg>
        </div>
        <div class="chart-legend">
          <span><i class="swatch s-primary" />Setor</span>
          <span><i class="swatch s-accent" />Tarik</span>
        </div>
        </template>
        <p v-else class="muted">Belum ada data arus kas 6 bulan terakhir. Muat ulang halaman setelah backend tersedia.</p>
      </section>

      <section class="panel span-4">
        <h2>Komposisi Dana</h2>
        <p class="sub">Total 6 bulan terakhir</p>
        <div v-if="flow.length" class="donut-row">
          <div class="chart-wrap dash-donut">
            <svg viewBox="0 0 116 116" role="img" aria-label="Donat komposisi dana">
              <circle class="d-track" cx="58" cy="58" r="44" fill="none" stroke-width="18" />
              <circle
                class="donut-arc donut-arc-setor d1"
                cx="58" cy="58" r="44" fill="none" stroke-width="18"
                :stroke-dasharray="`${donutSegs.setorLen} ${donutSegs.C}`"
                :style="{ '--seg': donutSegs.setorLen }"
                transform="rotate(-90 58 58)"
              />
              <circle
                class="donut-arc donut-arc-tarik d2"
                cx="58" cy="58" r="44" fill="none" stroke-width="18"
                :stroke-dasharray="`${donutSegs.tarikLen} ${donutSegs.C}`"
                :stroke-dashoffset="donutSegs.tarikOff"
                :style="{ '--seg': donutSegs.tarikLen, '--C': donutSegs.C }"
                transform="rotate(-90 58 58)"
              />
              <text class="t-val" x="58" y="58" text-anchor="middle" font-size="17">
                {{ donut.setorPct.toFixed(0) }}%
              </text>
              <text class="t-axis" x="58" y="71" text-anchor="middle" font-size="10">setor</text>
            </svg>
          </div>
          <ul class="donut-list">
            <li><span><i class="swatch s-primary" />Setor</span><strong class="num">{{ formatRupiah(donut.setor) }}</strong></li>
            <li><span><i class="swatch s-accent" />Tarik</span><strong class="num">{{ formatRupiah(donut.tarik) }}</strong></li>
          </ul>
        </div>
        <p v-else class="muted">Belum ada data komposisi dana untuk periode ini.</p>
      </section>

      <section class="panel span-5">
        <h2>Transaksi Terbaru</h2>
        <div v-if="recent.length" class="table-scroll">
        <table>
          <thead>
            <tr><th class="hide-sm">Tanggal</th><th>Nasabah</th><th>Jenis</th><th class="ta-r">Nominal</th></tr>
          </thead>
          <tbody>
            <tr v-for="t in recent" :key="t.id">
              <td class="hide-sm">{{ t.tanggal }}</td>
              <td>{{ t.nasabah }}<span class="cell-sub show-sm">{{ t.tanggal }}</span></td>
              <td><span :class="['badge', t.jenis === 'SETOR' ? 'in' : 'out']">{{ t.jenis }}</span></td>
              <td class="ta-r num">{{ formatRupiah(t.nominal) }}</td>
            </tr>
          </tbody>
        </table>
        </div>
        <p v-else class="muted">Belum ada transaksi tercatat. Muat ulang halaman setelah backend tersedia.</p>
      </section>

      <!-- Area khusus login (v-if) -->
      <section v-if="isLoggedIn" class="panel span-7">
        <h2>Insight Nasabah Prioritas</h2>
        <p v-if="loadingPremium" class="muted">Memuat nasabah prioritas dan laba rugi…</p>
        <div v-else class="insight">
          <div>
            <h3>Simpanan terbesar</h3>
            <div v-if="topDeposits.length" class="table-scroll">
            <table>
              <thead>
                <tr><th>Nasabah</th><th class="ta-r">Rekening</th><th class="ta-r">Total Saldo</th></tr>
              </thead>
              <tbody>
                <tr v-for="t in topDeposits" :key="t.nama">
                  <td>{{ t.nama }}<span class="cell-sub">{{ t.kota }}</span></td>
                  <td class="ta-r num">{{ t.jumlah_rekening }}</td>
                  <td class="ta-r num">{{ formatRupiah(t.total_saldo) }}</td>
                </tr>
              </tbody>
            </table>
            </div>
            <p v-else class="muted">Belum ada data nasabah prioritas.</p>
          </div>
          <div>
            <h3>Laba/rugi per bulan</h3>
            <div v-if="labaBars" class="chart-wrap">
              <svg viewBox="0 0 300 180" role="img" aria-label="Diagram batang laba rugi per bulan">
                <line class="l-zero" x1="0" :y1="labaBars.yZero" x2="300" :y2="labaBars.yZero" />
                <g v-for="(b, bi) in labaBars.rows" :key="b.bulan" :style="{ '--i': bi }">
                  <rect class="svg-bar" :class="b.neg ? 'neg s-down' : 's-up'" :x="b.x" :width="b.w" :y="b.ry" :height="b.h" rx="3">
                    <title>{{ b.label }}: {{ formatRupiah(b.val) }}{{ b.neg ? ' (rugi)' : '' }}</title>
                  </rect>
                  <text class="svg-bar-val t-val" :class="b.neg ? 't-down' : 't-up'" :x="b.cx" :y="b.labelY" text-anchor="middle" font-size="11.5">{{ b.lab }}</text>
                  <text class="svg-bar-x t-axis" :x="b.cx" y="172" text-anchor="middle" font-size="12">{{ b.label }}</text>
                </g>
              </svg>
            </div>
            <p v-else class="muted">Belum ada data laba/rugi 6 bulan terakhir.</p>
            <p class="muted small">Setor dikurangi tarik, 6 bulan terakhir.</p>
          </div>
        </div>
      </section>

      <section v-else class="panel locked span-7">
        <h2>Insight Nasabah Prioritas</h2>
        <p class="muted">Login untuk melihat nasabah prioritas dan laba rugi per bulan. Data ini disembunyikan untuk tamu.</p>
        <button class="btn" @click="router.push({ name: 'login', query: { redirect: '/' } })">Login untuk melihat</button>
      </section>
    </div>
  </div>
</template>
