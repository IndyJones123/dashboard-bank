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
  const yZero = 94 - ((0 - yMin) / range) * 78
  const step = 444 / rows.length
  return {
    yZero,
    rows: rows.map((r, i) => {
      const yv = 94 - ((r.laba - yMin) / range) * 78
      const cx = 16 + step * (i + 0.5)
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
        <p class="muted small">Ringkasan kinerja bank, data publik, update harian.</p>
      </div>
      <span v-if="isLoggedIn" class="badge in">LOGIN</span>
      <span v-else class="badge info">TAMU</span>
    </div>

    <p v-if="error" class="alert">{{ error }}</p>
    <p v-if="loading" class="muted">Memuat data…</p>

    <!-- Kartu statistik -->
    <section v-if="stats" class="cards">
      <div class="card">
        <div class="card-ico blue" aria-hidden="true">
          <svg class="ico-svg" viewBox="0 0 24 24"><path d="M16 19v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 17.5V19M10 10.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6M20 19v-1.5a3.5 3.5 0 0 0-2.6-3.4M15.5 4.6a3 3 0 0 1 0 5.8" /></svg>
        </div>
        <div class="card-body">
          <span class="label">Total Nasabah</span>
          <strong>{{ stats.total_nasabah?.toLocaleString('id-ID') ?? '–' }}</strong>
          <span class="muted small">terdaftar aktif</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico green" aria-hidden="true">
          <svg class="ico-svg" viewBox="0 0 24 24"><path d="M3 7.5A2.5 2.5 0 0 1 5.5 5h11A2.5 2.5 0 0 1 19 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 3 16.5zM3 9.5h18M7 14.5h4" /></svg>
        </div>
        <div class="card-body">
          <span class="label">Total Simpanan</span>
          <strong>{{ formatRupiah(stats.total_simpanan) }}</strong>
          <span class="muted small">akumulasi rekening</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico amber" aria-hidden="true">
          <svg class="ico-svg" viewBox="0 0 24 24"><path d="M4 8h12.5M13.5 5 16.5 8l-3 3M20 16H7.5M10.5 13l-3 3 3 3" /></svg>
        </div>
        <div class="card-body">
          <span class="label">Transaksi Hari Ini</span>
          <strong>{{ stats.transaksi_hari_ini?.toLocaleString('id-ID') ?? '–' }}</strong>
          <span class="muted small">setor + tarik</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico red" aria-hidden="true">
          <svg class="ico-svg" viewBox="0 0 24 24"><path d="M6 3.5h8l4 4v13H6zM14 3.5v4h4M9.5 13h5M9.5 16.5h5" /></svg>
        </div>
        <div class="card-body">
          <span class="label">Kredit Berjalan</span>
          <strong>{{ formatRupiah(stats.kredit_berjalan) }}</strong>
          <span class="muted small">sisa pokok</span>
        </div>
      </div>
    </section>

    <!-- 4 kuadran kompak: grafik, donat, transaksi, insight (1 layar) -->
    <div class="dash-grid">
      <div class="panel">
        <h2>Arus Kas 6 Bulan Terakhir</h2>
        <p class="sub">
          Setor vs tarik per bulan
          <span v-if="setorDelta !== null" :class="['delta', setorDelta >= 0 ? 'up' : 'down']">
            {{ setorDelta >= 0 ? '▲' : '▼' }} {{ Math.abs(setorDelta).toFixed(1) }}% setor MoM
          </span>
        </p>
        <template v-if="flow.length">
        <div class="chart-wrap">
          <svg viewBox="0 0 560 180" role="img" aria-label="Grafik arus kas">
            <g v-for="g in [0, 1, 2, 3, 4]" :key="g">
              <line x1="44" :y1="40 + g * 30" x2="550" :y2="40 + g * 30" stroke="rgba(10,25,47,0.10)" stroke-width="1" />
              <text x="38" :y="44 + g * 30" text-anchor="end" font-size="10" fill="#475569">
                {{ (maxFlow * (4 - g) / 4 / 1e9).toFixed(0) }}M
              </text>
            </g>
            <g v-for="(b, bi) in flowBars" :key="b.bulan" :style="{ '--i': bi }">
              <rect
                class="svg-bar"
                :x="b.xSetor" :width="26"
                :y="b.ySetor" :height="160 - b.ySetor"
                rx="4" fill="#059669"
              >
                <title>Setor {{ b.bulan }}: {{ formatRupiah(b.setor) }}</title>
              </rect>
              <rect
                class="svg-bar"
                :x="b.xTarik" :width="26"
                :y="b.yTarik" :height="160 - b.yTarik"
                rx="4" fill="#0a192f"
              >
                <title>Tarik {{ b.bulan }}: {{ formatRupiah(b.tarik) }}</title>
              </rect>
              <!-- Nilai terlihat di atas tiap batang (tanpa hover) -->
              <text class="svg-bar-val" :x="b.xSetor + 13" :y="b.ySetor - 5" text-anchor="middle" font-size="9.5" font-weight="700" fill="#047857">{{ b.vSetor }}</text>
              <text class="svg-bar-val" :x="b.xTarik + 13" :y="b.yTarik - 5" text-anchor="middle" font-size="9.5" font-weight="700" fill="#0a192f">{{ b.vTarik }}</text>
              <text class="svg-bar-x" :x="b.xSetor + 27" y="175" text-anchor="middle" font-size="11" fill="#475569">
                {{ b.label }}
              </text>
            </g>
          </svg>
        </div>
        <div class="chart-legend">
          <span><i class="swatch" style="background: #059669" />Setor</span>
          <span><i class="swatch" style="background: #0a192f" />Tarik</span>
        </div>
        </template>
        <p v-else class="muted small">Belum ada data arus kas 6 bulan terakhir. Muat ulang halaman setelah backend tersedia.</p>
      </div>

      <div class="panel">
        <h2>Komposisi Dana</h2>
        <p class="sub">Total 6 bulan terakhir</p>
        <template v-if="flow.length">
        <div class="chart-wrap dash-donut">
          <svg viewBox="0 0 200 116" role="img" aria-label="Donat komposisi dana">
            <circle cx="100" cy="54" r="44" fill="none" stroke="rgba(10,25,47,0.10)" stroke-width="18" />
            <circle
              class="donut-arc donut-arc-setor"
              cx="100" cy="54" r="44" fill="none" stroke="#059669" stroke-width="18"
              :stroke-dasharray="`${donutSegs.setorLen} ${donutSegs.C}`"
              :style="{ '--seg': donutSegs.setorLen }"
              transform="rotate(-90 100 54)" stroke-linecap="round"
            />
            <circle
              class="donut-arc donut-arc-tarik"
              cx="100" cy="54" r="44" fill="none" stroke="#0a192f" stroke-width="18"
              :stroke-dasharray="`${donutSegs.tarikLen} ${donutSegs.C}`"
              :stroke-dashoffset="donutSegs.tarikOff"
              :style="{ '--seg': donutSegs.tarikLen, '--C': donutSegs.C }"
              transform="rotate(-90 100 54)" stroke-linecap="round"
            />
            <text x="100" y="51" text-anchor="middle" font-size="15" font-weight="800" fill="#191c1e">
              {{ donut.setorPct.toFixed(0) }}%
            </text>
            <text x="100" y="67" text-anchor="middle" font-size="10" fill="#475569">setor</text>
          </svg>
        </div>
        <ul class="donut-list">
          <li><span><i class="swatch" style="background: #059669" />Setor</span><strong>{{ formatRupiah(donut.setor) }}</strong></li>
          <li><span><i class="swatch" style="background: #0a192f" />Tarik</span><strong>{{ formatRupiah(donut.tarik) }}</strong></li>
        </ul>
        </template>
        <p v-else class="muted small">Belum ada data komposisi dana untuk periode ini.</p>
      </div>

    <!-- Transaksi terbaru -->
    <section class="panel">
      <h2>Transaksi Terbaru</h2>
      <div v-if="recent.length" class="table-scroll">
      <table>
        <thead>
          <tr><th>Tanggal</th><th>Nasabah</th><th>Jenis</th><th>Nominal</th></tr>
        </thead>
        <tbody>
          <tr v-for="t in recent" :key="t.id">
            <td>{{ t.tanggal }}</td>
            <td>{{ t.nasabah }}</td>
            <td><span :class="['badge', t.jenis === 'SETOR' ? 'in' : 'out']">{{ t.jenis }}</span></td>
            <td>{{ formatRupiah(t.nominal) }}</td>
          </tr>
        </tbody>
      </table>
      </div>
      <p v-else class="muted small">Belum ada transaksi tercatat. Muat ulang halaman setelah backend tersedia.</p>
    </section>

    <!-- Area khusus login (v-if) -->
    <section v-if="isLoggedIn" class="panel premium">
      <h2>Insight Nasabah Prioritas <span class="badge in">LOGIN</span></h2>
      <p v-if="loadingPremium" class="muted">Memuat data premium…</p>
      <template v-else>
        <div v-if="topDeposits.length" class="table-scroll">
        <table>
          <thead>
            <tr><th>Nasabah</th><th>Kota</th><th>Rekening</th><th>Total Saldo</th></tr>
          </thead>
          <tbody>
            <tr v-for="t in topDeposits" :key="t.nama">
              <td>{{ t.nama }}</td>
              <td>{{ t.kota }}</td>
              <td>{{ t.jumlah_rekening }}</td>
              <td>{{ formatRupiah(t.total_saldo) }}</td>
            </tr>
          </tbody>
        </table>
        </div>
        <p v-else class="muted small">Belum ada data top deposan.</p>
        <p class="sub">Laba/Rugi per Bulan (setor - tarik, 6 bulan terakhir)</p>
        <div v-if="labaBars" class="chart-wrap">
          <svg viewBox="0 0 480 120" role="img" aria-label="Diagram batang laba rugi per bulan">
            <line x1="16" :y1="labaBars.yZero" x2="464" :y2="labaBars.yZero" stroke="rgba(10,25,47,0.35)" stroke-width="1" />
            <g v-for="(b, bi) in labaBars.rows" :key="b.bulan" :style="{ '--i': bi }">
              <rect class="svg-bar" :class="{ neg: b.neg }" :x="b.x" :width="b.w" :y="b.ry" :height="b.h" rx="3" :fill="b.neg ? '#dc2626' : '#059669'">
                <title>{{ b.label }}: {{ formatRupiah(b.val) }}{{ b.neg ? ' (rugi)' : '' }}</title>
              </rect>
              <text class="svg-bar-val" :x="b.cx" :y="b.labelY" text-anchor="middle" font-size="9.5" font-weight="700" :fill="b.neg ? '#b91c1c' : '#047857'">{{ b.lab }}</text>
              <text class="svg-bar-x" :x="b.cx" y="112" text-anchor="middle" font-size="10" fill="#475569">{{ b.label }}</text>
            </g>
          </svg>
        </div>
        <p v-else class="muted small">Belum ada data laba/rugi 6 bulan terakhir.</p>
      </template>
    </section>

    <section v-else class="panel locked">
      <h2>Insight Nasabah Prioritas (login)</h2>
      <p class="muted">Bagian ini hanya terlihat setelah login. Data top deposan &amp; laba bunga disembunyikan untuk tamu.</p>
      <button class="btn" @click="router.push({ name: 'login', query: { redirect: '/' } })">Login untuk melihat</button>
    </section>
    </div>
  </div>
</template>
