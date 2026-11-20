<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import api from '../api'
import { apiErrText } from '../report-helpers'
import { DPD, RISK_COLORS, type Row, dateLabel, intText, sumOf, sysDate } from '../pby-helpers'
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'
import type { PbyCol } from './PbyTable.vue'
import PbyList from './PbyList.vue'
import PbyStack, { type StackSeg } from './PbyStack.vue'
import RpValue from './RpValue.vue'

/* ==========================================================================
   PEMBIAYAAN · TAGIHAN & TUNGGAKAN
   Sumber (be/QueryData/pembiayaan, dieksekusi apa adanya lewat BE):
     Umur tunggakan (DPD) : Pembiayaan DPD Revisi.sql   (seksi AO, Lokasi & Produk)
     Tunggakan            : Pembiayaan Tunggakan.sql    (seksi Lokasi & Produk, AO, Nasabah)
   Keduanya memakai tanggal sistem dari tabel Tanggal (posisi hari ini).
   ========================================================================== */

const w = useWidgets('pembiayaan-tagihan')

type View = 'lokasi' | 'ao'

const dpd = reactive({ view: 'lokasi' as View, loading: true, error: '', lokasi: [] as Row[], ao: [] as Row[] })
const tgk = reactive({
  view: 'lokasi' as View, loading: true, error: '',
  lokasi: [] as Row[], ao: [] as Row[], nasabah: [] as Row[],
})

async function loadDpd(): Promise<void> {
  dpd.loading = true
  dpd.error = ''
  try {
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[] }>('/api/pembiayaan/dpd', { timeout: 90000 })
    dpd.lokasi = data.lokasi ?? []
    dpd.ao = data.ao ?? []
  } catch (e) {
    dpd.error = apiErrText(e, 'Gagal memuat umur tunggakan. Pastikan BE jalan.')
  } finally {
    dpd.loading = false
  }
}

async function loadTgk(): Promise<void> {
  tgk.loading = true
  tgk.error = ''
  try {
    const { data } = await api.get<{ lokasi?: Row[]; ao?: Row[]; nasabah?: Row[] }>('/api/pembiayaan/tunggakan', { timeout: 90000 })
    tgk.lokasi = data.lokasi ?? []
    tgk.ao = data.ao ?? []
    tgk.nasabah = data.nasabah ?? []
  } catch (e) {
    tgk.error = apiErrText(e, 'Gagal memuat tunggakan. Pastikan BE jalan.')
  } finally {
    tgk.loading = false
  }
}

const subLabel = (key: string) => (r: Row): string => `Subtotal ${String(r[key] ?? '')}`

/* ---------- Ringkasan ---------- */
const totTgk = computed(() => sumOf(tgk.lokasi, 'tgk'))
const totTgkMdl = computed(() => sumOf(tgk.lokasi, 'tgkmdl'))
const totTgkMgn = computed(() => sumOf(tgk.lokasi, 'tgkmgn'))
const dpdOver90 = computed(() => sumOf(dpd.lokasi, 'D091_180') + sumOf(dpd.lokasi, 'D181_360') + sumOf(dpd.lokasi, 'D361_999'))
const dpdOver90Noa = computed(() => sumOf(dpd.lokasi, 'Q3') + sumOf(dpd.lokasi, 'Q4') + sumOf(dpd.lokasi, 'Q5'))

/* ---------- DPD ---------- */
const dpdSegs = computed<StackSeg[]>(() =>
  DPD.map((b, i) => ({
    key: b.d, label: b.label, value: sumOf(dpd.lokasi, b.d), color: RISK_COLORS[i],
    note: `${intText(sumOf(dpd.lokasi, b.q))} NOA`,
  })),
)
const dpdCols = computed<PbyCol[]>(() => [
  ...(dpd.view === 'lokasi'
    ? [
        { key: 'nmkantor', label: 'Kantor', sub: 'kdloc' },
        { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
      ]
    : [{ key: 'nmao', label: 'AO', sub: 'kdaoh' }]),
  ...DPD.flatMap((b) => [
    { key: b.q, label: 'NOA', fmt: 'int' as const, group: b.label },
    { key: b.d, label: 'OS (Rp)', fmt: 'rp' as const, group: b.label },
  ]),
])

/* ---------- Tunggakan ---------- */
const tgkCols = computed<PbyCol[]>(() => [
  ...(tgk.view === 'lokasi'
    ? [
        { key: 'nmcabang', label: 'Kantor', sub: 'kdloc' },
        { key: 'nmprd', label: 'Produk', sub: 'kdprd' },
      ]
    : [{ key: 'nmao', label: 'AO', sub: 'kdaoh' }]),
  { key: 'osmdlc', label: 'Pokok', fmt: 'rp', group: 'Outstanding (Rp)' },
  { key: 'osmgnc', label: 'Margin', fmt: 'rp', group: 'Outstanding (Rp)' },
  { key: 'tgkmdl', label: 'Pokok', fmt: 'rp', group: 'Tunggakan (Rp)' },
  { key: 'tgkmgn', label: 'Margin', fmt: 'rp', group: 'Tunggakan (Rp)' },
  { key: 'tgk', label: 'Total', fmt: 'rp', group: 'Tunggakan (Rp)' },
])

/* ---------- Daftar nasabah ---------- */
const q = ref('')
const kantorF = ref('')
const nsbKantors = computed(() => [...new Set(tgk.nasabah.map((r) => String(r.kdloc)))].sort())
const nsbRows = computed(() => {
  const s = q.value.trim().toLowerCase()
  return tgk.nasabah
    .filter((r) => !kantorF.value || String(r.kdloc) === kantorF.value)
    .filter((r) => !s || ['nama', 'nokontrak', 'nocif'].some((k) => String(r[k] ?? '').toLowerCase().includes(s)))
    .sort((a, b) => Number(b.tgk) - Number(a.tgk))
})
const nsbCols: PbyCol[] = [
  { key: 'nama', label: 'Nasabah', sub: 'nocif' },
  { key: 'nokontrak', label: 'No. Kontrak' },
  { key: 'kdloc', label: 'Kantor' },
  { key: 'kdprd', label: 'Produk' },
  { key: 'colbaru', label: 'Kol' },
  { key: 'osmdlc', label: 'Pokok', fmt: 'rp', group: 'Outstanding (Rp)' },
  { key: 'osmgnc', label: 'Margin', fmt: 'rp', group: 'Outstanding (Rp)' },
  { key: 'qty', label: 'Angsuran', fmt: 'int', group: 'Tunggakan' },
  { key: 'tgkmdl', label: 'Pokok (Rp)', fmt: 'rp', group: 'Tunggakan' },
  { key: 'tgkmgn', label: 'Margin (Rp)', fmt: 'rp', group: 'Tunggakan' },
  { key: 'tgk', label: 'Total (Rp)', fmt: 'rp', group: 'Tunggakan' },
]

const tgl = ref<string | null>(null)

onMounted(async () => {
  void loadDpd()
  void loadTgk()
  tgl.value = await sysDate()
})
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Tagihan &amp; Tunggakan</h1>
        <p>
          Umur tunggakan (DPD) dan tagihan jatuh tempo yang belum dibayar.
          <template v-if="tgl">Tanggal sistem: <strong>{{ dateLabel(tgl) }}</strong>.</template>
        </p>
      </div>
    </div>

    <WidgetNotice :w="w" />
    <div class="wgrid">
      <section v-if="w.show('angka-utama')" class="w lead-part hero" :style="w.style('angka-utama')">
        <p class="lead-label">Total Tunggakan</p>
        <p class="lead-value num"><RpValue :value="tgk.loading ? null : Math.round(totTgk)" /></p>
        <p class="lead-note">{{ tgk.loading ? '–' : intText(tgk.nasabah.length) }} kontrak menunggak</p>
      </section>
      <section v-if="w.show('ringkasan')" class="w lead-part" :style="w.style('ringkasan')">
        <dl class="ledger">
          <div>
            <dt>Tunggakan pokok</dt>
            <dd class="num"><RpValue :value="tgk.loading ? null : Math.round(totTgkMdl)" /></dd>
          </div>
          <div>
            <dt>Tunggakan margin</dt>
            <dd class="num"><RpValue :value="tgk.loading ? null : Math.round(totTgkMgn)" /></dd>
          </div>
          <div>
            <dt>OS dengan DPD &gt; 90 hari <small>{{ dpd.loading ? '–' : intText(dpdOver90Noa) }} NOA</small></dt>
            <dd class="num" :class="dpdOver90 > 0 ? 'g-down' : ''"><RpValue :value="dpd.loading ? null : Math.round(dpdOver90)" /></dd>
          </div>
        </dl>
      </section>

      <!-- DPD -->
      <section v-if="w.show('dpd')" class="w panel" :style="w.style('dpd')">
        <div class="pby-head">
          <div>
            <h2>Umur Tunggakan (DPD)</h2>
            <p class="sub">Outstanding pokok dikelompokkan menurut hari tunggakan terlama (pokok atau margin).</p>
          </div>
          <div class="pby-ctrl">
            <div class="segmented" role="group" aria-label="Kelompokkan DPD">
              <button type="button" :class="{ on: dpd.view === 'lokasi' }" @click="dpd.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: dpd.view === 'ao' }" @click="dpd.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="dpd.loading" class="muted">Memuat umur tunggakan…</p>
        <p v-else-if="dpd.error" class="alert">{{ dpd.error }}</p>
        <template v-else>
          <PbyStack :segs="dpdSegs" label="Komposisi outstanding per umur tunggakan" />
          <PbyList
            :cols="dpdCols" :rows="dpd.view === 'lokasi' ? dpd.lokasi : dpd.ao"
            :subtotal-by="dpd.view === 'lokasi' ? 'kdloc' : undefined"
            :subtotal-label="subLabel('nmkantor')"
          />
        </template>
      </section>

      <!-- Tunggakan -->
      <section v-if="w.show('tunggakan')" class="w panel" :style="w.style('tunggakan')">
        <div class="pby-head">
          <div>
            <h2>Tunggakan</h2>
            <p class="sub">Tagihan jatuh tempo s.d. hari ini yang belum dibayar, untuk kontrak aktif.</p>
          </div>
          <div class="pby-ctrl">
            <div class="segmented" role="group" aria-label="Kelompokkan tunggakan">
              <button type="button" :class="{ on: tgk.view === 'lokasi' }" @click="tgk.view = 'lokasi'">Kantor &amp; Produk</button>
              <button type="button" :class="{ on: tgk.view === 'ao' }" @click="tgk.view = 'ao'">AO</button>
            </div>
          </div>
        </div>
        <p v-if="tgk.loading" class="muted">Memuat tunggakan…</p>
        <p v-else-if="tgk.error" class="alert">{{ tgk.error }}</p>
        <PbyList
          v-else :cols="tgkCols" head-key="tgk" :rows="tgk.view === 'lokasi' ? tgk.lokasi : tgk.ao"
          :subtotal-by="tgk.view === 'lokasi' ? 'kdloc' : undefined"
          :subtotal-label="subLabel('nmcabang')"
          empty="Tidak ada tunggakan."
        />
      </section>

      <!-- Nasabah menunggak -->
      <section v-if="w.show('nasabah')" class="w panel" :style="w.style('nasabah')">
        <div class="pby-head">
          <div>
            <h2>Nasabah Menunggak</h2>
            <p class="sub">Diurutkan dari tunggakan terbesar.</p>
          </div>
          <div class="pby-ctrl filters">
            <label>
              Kantor
              <select v-model="kantorF">
                <option value="">Semua</option>
                <option v-for="k in nsbKantors" :key="k" :value="k">{{ k }}</option>
              </select>
            </label>
            <input v-model="q" type="search" placeholder="Cari nama, kontrak, CIF" aria-label="Cari nasabah" />
          </div>
        </div>
        <p v-if="tgk.loading" class="muted">Memuat daftar nasabah…</p>
        <p v-else-if="tgk.error" class="alert">{{ tgk.error }}</p>
        <PbyList
          v-else :cols="nsbCols" head-key="tgk" :rows="nsbRows" :per-page="15"
          :empty="q || kantorF ? 'Tidak ada nasabah yang cocok.' : 'Tidak ada nasabah menunggak.'"
        />
      </section>
    </div>
  </div>
</template>
