<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'
import { apiErrText, formatRpSingkat } from '../report-helpers'
import MoreDetails from './MoreDetails.vue'

/* ==========================================================================
   LAPORAN KEUANGAN HARIAN: /api/laporan/harian
   Port dari be/QueryData/Laporan-Keuangan-Harian.sql (18 baris UNION ALL):
   Kas, Bank, dropping, outstanding pokok, angsuran/pelunasan (hari ini &
   bulan ini), NPL/NPF OJK+internal, pendapatan/biaya/laba rugi.
   Urut 12 & 14 (NPF) satuan PERSEN, bukan Rupiah.
   ========================================================================== */

interface LkhRow {
  urut: string
  ket: string
  saldo: number | null
}

const tanggal = ref(new Date().toISOString().slice(0, 10))
const kdloc = ref('00')
const offices = ref<string[]>(['00'])
const rows = ref<LkhRow[]>([])
const loading = ref(true)
const error = ref('')
/** Tabel terperinci default tersembunyi; dibuka via tombol More details. */
const detOpen = ref(false)

const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

/** 2026-10-21 -> "21 Oktober 2026" */
const tanggalIndo = computed(() => {
  const [y, m, d] = tanggal.value.split('-').map(Number)
  return `${d} ${BULAN[m - 1]} ${y}`
})

const isPct = (r: LkhRow): boolean => r.urut === '12' || r.urut === '14'
const fmt = (r: LkhRow): string => {
  if (r.saldo === null || r.saldo === undefined) return '–'
  return isPct(r) ? `${Number(r.saldo).toFixed(2)} %` : formatRpSingkat(r.saldo)
}

/** Nilai kartu: placeholder saat loading / datanya null, persen utk NPF.
    Rupiah disingkat (T/M/jt) — lihat formatRpSingkat. */
const cardVal = (v: number | null, pct = false): string => {
  if (loading.value || v == null || Number.isNaN(v)) return '–'
  return pct ? `${Number(v).toFixed(2)} %` : formatRpSingkat(v)
}
const cardFull = (v: number | null, pct = false): string => {
  if (v == null || Number.isNaN(v)) return '–'
  return pct ? `${Number(v).toFixed(2)} %` : formatRupiah(v)
}

/** Pengelompokan 18 baris (urut query asli) jadi bagian-bagian laporan. */
const SECTIONS: { title: string; uruts: string[] }[] = [
  { title: 'I. Posisi Kas & Bank', uruts: ['01', '02'] },
  { title: 'II. Penyaluran (Dropping) Hari Ini', uruts: ['03'] },
  { title: 'III. Outstanding Pinjaman', uruts: ['04', '05', '06'] },
  { title: 'IV. Angsuran & Pelunasan', uruts: ['07', '08', '09', '10'] },
  { title: 'V. Kualitas Aset (NPL / NPF)', uruts: ['11', '12', '13', '14'] },
  { title: 'VI. Pendapatan, Biaya & Laba Rugi', uruts: ['15', '16', '17', '18'] },
]

const byUrut = (u: string): LkhRow | undefined => rows.value.find((r) => r.urut === u)
const sections = computed(() =>
  SECTIONS.map((s) => ({
    ...s,
    rows: s.uruts
      .map((u) => byUrut(u))
      .filter((r): r is LkhRow => !!r),
  })),
)

const kas = computed(() => byUrut('01')?.saldo ?? null)
const bank = computed(() => byUrut('02')?.saldo ?? null)
const totalOS = computed(() => byUrut('06')?.saldo ?? null)
const npfOjk = computed(() => byUrut('12')?.saldo ?? null)
const labaBerjalan = computed(() => byUrut('18')?.saldo ?? null)

async function loadOffices(): Promise<void> {
  try {
    const { data } = await api.get<{ kdloc: string }[]>('/api/gl/offices')
    offices.value = ['00', ...data.map((o) => String(o.kdloc))]
  } catch {
    offices.value = ['00']
  }
}

async function load(): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    const { data } = await api.get<{ rows: LkhRow[] }>('/api/laporan/harian', {
      params: { tanggal: tanggal.value, kdloc: kdloc.value },
    })
    rows.value = data.rows ?? []
  } catch (e) {
    rows.value = []
    error.value = apiErrText(e, 'Gagal memuat laporan harian. Pastikan BE jalan.')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void loadOffices()
  void load()
})
</script>

<template>
  <div>
    <!-- Filter laporan harian -->
    <section class="panel">
      <div class="toolbar">
        <div class="filters">
          <label>
            Tanggal
            <input v-model="tanggal" type="date" @change="load">
          </label>
          <label>
            Kantor
            <select v-model="kdloc" @change="load">
              <option value="00">Semua Kantor</option>
              <option v-for="o in offices.filter((v) => v !== '00')" :key="o" :value="o">Kantor {{ o }}</option>
            </select>
          </label>
        </div>
        <span v-if="loading" class="muted small">Memuat…</span>
      </div>
    </section>

    <!-- Ringkasan posisi harian: nilai ringkas (T/M/jt) supaya tak overflow -->
    <section class="cards sum">
      <div class="card metric">
        <span class="label">Kas</span>
        <strong class="num" :title="cardFull(kas)">{{ cardVal(kas) }}</strong>
        <span class="muted small">Posisi hari ini</span>
      </div>
      <div class="card metric">
        <span class="label">Bank</span>
        <strong class="num" :title="cardFull(bank)">{{ cardVal(bank) }}</strong>
        <span class="muted small">Giro &amp; tabungan</span>
      </div>
      <div class="card metric">
        <span class="label">Total OS Pokok</span>
        <strong class="num" :title="cardFull(totalOS)">{{ cardVal(totalOS) }}</strong>
        <span class="muted small">Outstanding portofolio</span>
      </div>
      <div class="card metric">
        <span class="label">NPF OJK</span>
        <strong class="num" :title="cardFull(npfOjk, true)">{{ cardVal(npfOjk, true) }}</strong>
        <span class="muted small">Batas sehat &lt; 5%</span>
      </div>
      <div class="card metric">
        <span class="label">Laba Bulan Berjalan</span>
        <strong class="num" :title="cardFull(labaBerjalan)">{{ cardVal(labaBerjalan) }}</strong>
        <span class="muted small">Rugi laba MTD</span>
      </div>
    </section>

    <!-- Perincian: satu tabel berkelompok, tanggal format Indonesia -->
    <section class="panel">
      <h2>Perincian Laporan Keuangan Harian</h2>
      <p class="sub">
        {{ tanggalIndo }} · Kantor {{ kdloc === '00' ? 'Semua Kantor' : `Kantor ${kdloc}` }}
      </p>
      <p v-if="loading" class="muted">Memuat laporan harian…</p>
      <p v-else-if="error" class="alert">{{ error }}</p>
      <p v-else-if="!rows.length" class="muted">Belum ada data untuk tanggal ini. Coba pilih tanggal atau kantor lain.</p>
      <template v-else>
        <MoreDetails id="det-harian" :open="detOpen" @toggle="detOpen = !detOpen">
          <div class="table-scroll">
          <table class="harian">
            <thead>
              <tr>
                <th class="ta-c urut-col">Urut</th>
                <th>Uraian</th>
                <th class="ta-r">Nilai</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="s in sections" :key="s.title">
                <tr class="grp">
                  <td colspan="3">{{ s.title }}</td>
                </tr>
                <tr v-for="r in s.rows" :key="r.urut">
                  <td class="ta-c muted urut-col">{{ r.urut }}</td>
                  <td>{{ r.ket }}</td>
                  <td class="ta-r num" :class="{ pct: isPct(r) }"
                      :title="isPct(r) ? undefined : formatRupiah(r.saldo)">{{ fmt(r) }}</td>
                </tr>
              </template>
            </tbody>
          </table>
          </div>
          <p class="muted small note">
            Sumber: Laporan-Keuangan-Harian.sql · NPL dalam Rupiah, NPF dalam persen ·
            Filter kantor memengaruhi nilai konsolidasi (range kodeloc).
          </p>
        </MoreDetails>
      </template>
    </section>
  </div>
</template>

<style scoped>
/* Kartu ringkas: angka pendek + ruang lebih rapat, tetap 1 baris di lebar kecil */
.sum { grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 0.6rem; }
.sum .card { padding: 0.55rem 0.8rem; gap: 0.2rem; }
.sum .card.metric strong { font-size: 1.55rem; line-height: 1.2; white-space: nowrap; }
.sum .card .small { font-size: 0.85rem; }

/* Perincian: header grup jadi pembatas bagian (tanpa 6 tabel terpisah) */
.harian .grp td {
  background: var(--surface-2);
  border-left: 3px solid var(--primary);
  color: var(--ink);
  font-size: 0.9rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  padding-top: 0.5rem;
  padding-bottom: 0.5rem;
}
.harian td.num { font-weight: 600; }
.num.pct { font-variant-numeric: tabular-nums; }
.urut-col { width: 3.4rem; }
.note { margin-top: 1rem; }
</style>
