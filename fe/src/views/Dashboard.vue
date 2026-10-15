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
  laba_bunga: number
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

// Segmen donat SVG (lingkaran r=54, keliling ≈ 339.29)
const donutSegs = computed(() => {
  const C = 2 * Math.PI * 54
  const s = (donut.value.setorPct / 100) * C
  return { C, setorLen: s, tarikLen: C - s, tarikOff: -s }
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
      api.get('/api/dashboard/top-deposits', { params: { limit: 5 } }),
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
        <p class="muted small">Ringkasan kinerja bank — data publik, update harian.</p>
      </div>
      <span v-if="isLoggedIn" class="badge in">LOGIN</span>
      <span v-else class="badge info">TAMU</span>
    </div>

    <p v-if="error" class="alert">{{ error }}</p>
    <p v-if="loading" class="muted">Memuat data…</p>

    <!-- Kartu statistik -->
    <section v-if="stats" class="cards">
      <div class="card">
        <div class="card-ico blue">👥</div>
        <div class="card-body">
          <span class="label">Total Nasabah</span>
          <strong>{{ stats.total_nasabah.toLocaleString('id-ID') }}</strong>
          <span class="muted small">terdaftar aktif</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico green">💰</div>
        <div class="card-body">
          <span class="label">Total Simpanan</span>
          <strong>{{ formatRupiah(stats.total_simpanan) }}</strong>
          <span class="muted small">akumulasi rekening</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico amber">🔁</div>
        <div class="card-body">
          <span class="label">Transaksi Hari Ini</span>
          <strong>{{ stats.transaksi_hari_ini.toLocaleString('id-ID') }}</strong>
          <span class="muted small">setor + tarik</span>
        </div>
      </div>
      <div class="card">
        <div class="card-ico red">📝</div>
        <div class="card-body">
          <span class="label">Kredit Berjalan</span>
          <strong>{{ formatRupiah(stats.kredit_berjalan) }}</strong>
          <span class="muted small">sisa pokok</span>
        </div>
      </div>
    </section>

    <!-- Grafik + donat -->
    <section class="grid-2">
      <div class="panel">
        <h2>Arus Kas 6 Bulan Terakhir</h2>
        <p class="sub">
          Setor vs tarik per bulan
          <span v-if="setorDelta !== null" :class="['delta', setorDelta >= 0 ? 'up' : 'down']">
            {{ setorDelta >= 0 ? '▲' : '▼' }} {{ Math.abs(setorDelta).toFixed(1) }}% setor MoM
          </span>
        </p>
        <div class="chart-wrap">
          <svg viewBox="0 0 560 260" role="img" aria-label="Grafik arus kas">
            <g v-for="g in [0, 1, 2, 3, 4]" :key="g">
              <line x1="44" :y1="20 + g * 50" x2="550" :y2="20 + g * 50" stroke="rgba(10,25,47,0.10)" stroke-width="1" />
              <text x="38" :y="24 + g * 50" text-anchor="end" font-size="10" fill="#475569">
                {{ (maxFlow * (4 - g) / 4 / 1e9).toFixed(0) }}M
              </text>
            </g>
            <g v-for="(f, i) in flow" :key="f.bulan">
              <rect
                :x="60 + i * 80" :width="30"
                :y="220 - (f.setor / maxFlow) * 190" :height="Math.max(3, (f.setor / maxFlow) * 190)"
                rx="4" fill="#059669"
              >
                <title>Setor {{ f.bulan }}: {{ formatRupiah(f.setor) }}</title>
              </rect>
              <rect
                :x="94 + i * 80" :width="30"
                :y="220 - (f.tarik / maxFlow) * 190" :height="Math.max(3, (f.tarik / maxFlow) * 190)"
                rx="4" fill="#0a192f"
              >
                <title>Tarik {{ f.bulan }}: {{ formatRupiah(f.tarik) }}</title>
              </rect>
              <text :x="92 + i * 80" y="238" text-anchor="middle" font-size="11" fill="#475569">
                {{ shortMonth(f.bulan) }}
              </text>
            </g>
          </svg>
        </div>
        <div class="chart-legend">
          <span><i class="swatch" style="background: #059669" />Setor</span>
          <span><i class="swatch" style="background: #0a192f" />Tarik</span>
        </div>
      </div>

      <div class="panel">
        <h2>Komposisi Dana</h2>
        <p class="sub">Total 6 bulan terakhir</p>
        <div class="chart-wrap">
          <svg viewBox="0 0 200 140" role="img" aria-label="Donat komposisi dana">
            <circle cx="100" cy="66" r="54" fill="none" stroke="rgba(10,25,47,0.10)" stroke-width="22" />
            <circle
              cx="100" cy="66" r="54" fill="none" stroke="#2563eb" stroke-width="22"
              :stroke-dasharray="`${donutSegs.setorLen} ${donutSegs.C}`"
              transform="rotate(-90 100 66)" stroke-linecap="round"
            />
            <circle
              cx="100" cy="66" r="54" fill="none" stroke="#14b8a6" stroke-width="22"
              :stroke-dasharray="`${donutSegs.tarikLen} ${donutSegs.C}`"
              :stroke-dashoffset="donutSegs.tarikOff"
              transform="rotate(-90 100 66)" stroke-linecap="round"
            />
            <text x="100" y="62" text-anchor="middle" font-size="15" font-weight="800" fill="#191c1e">
              {{ donut.setorPct.toFixed(0) }}%
            </text>
            <text x="100" y="78" text-anchor="middle" font-size="10" fill="#475569">setor</text>
          </svg>
        </div>
        <ul class="donut-list">
          <li><span><i class="swatch" style="background: #059669" />Setor</span><strong>{{ formatRupiah(donut.setor) }}</strong></li>
          <li><span><i class="swatch" style="background: #0a192f" />Tarik</span><strong>{{ formatRupiah(donut.tarik) }}</strong></li>
        </ul>
      </div>
    </section>

    <!-- Transaksi terbaru -->
    <section class="panel">
      <h2>Transaksi Terbaru</h2>
      <p class="sub">6 transaksi terakhir dari seluruh cabang</p>
      <div class="table-scroll">
      <table>
        <thead>
          <tr><th>Tanggal</th><th>Nasabah</th><th>Jenis</th><th>Nominal</th><th>Berita</th></tr>
        </thead>
        <tbody>
          <tr v-for="t in recent" :key="t.id">
            <td>{{ t.tanggal }}</td>
            <td>{{ t.nasabah }}<br /><small class="muted">{{ t.no_rekening }}</small></td>
            <td><span :class="['badge', t.jenis === 'SETOR' ? 'in' : 'out']">{{ t.jenis }}</span></td>
            <td>{{ formatRupiah(t.nominal) }}</td>
            <td>{{ t.berita }}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </section>

    <!-- Area khusus login (v-if) -->
    <section v-if="isLoggedIn" class="panel premium">
      <h2>Insight Nasabah Prioritas <span class="badge in">LOGIN</span></h2>
      <p v-if="loadingPremium" class="muted">Memuat data premium…</p>
      <template v-else>
        <div class="table-scroll">
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
        <h3>Laba Bunga per Bulan</h3>
        <ul class="profit">
          <li v-for="p in profit" :key="p.bulan">{{ p.bulan }} — <strong>{{ formatRupiah(p.laba_bunga) }}</strong></li>
        </ul>
      </template>
    </section>

    <section v-else class="panel locked">
      <h2>Insight Nasabah Prioritas 🔒</h2>
      <p class="muted">Bagian ini hanya terlihat setelah login. Data top deposan &amp; laba bunga disembunyikan untuk tamu.</p>
      <button class="btn" @click="router.push({ name: 'login', query: { redirect: '/' } })">Login untuk melihat</button>
    </section>
  </div>
</template>
