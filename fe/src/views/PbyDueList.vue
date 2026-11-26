<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import RpValue from './RpValue.vue'

/* ==========================================================================
   PbyDueList: daftar nasabah jatuh tempo, 1 KARTU per kontrak dgn data
   lengkap langsung tampil (tanpa buka rincian): nama, no. kontrak, lama
   lewat jatuh tempo, kantor, produk, kol, tgl jatuh tempo, jangka waktu,
   OS pokok, margin, total. Data persis dari query (Pembiayaan
   JatuhTempo.sql seksi "Daftar Nasabah"); berhalaman.
   ========================================================================== */

type Row = Record<string, unknown>
const props = withDefaults(
  defineProps<{
    rows: Row[]
    kantorNama?: Map<string, string>
    produkNama?: Map<string, string>
    perPage?: number
    empty?: string
  }>(),
  { perPage: 12, empty: 'Tidak ada data.' },
)

const page = ref(1)
watch(() => props.rows, () => { page.value = 1 })
const pageCount = computed(() => Math.max(1, Math.ceil(props.rows.length / props.perPage)))
const visible = computed(() => props.rows.slice((page.value - 1) * props.perPage, page.value * props.perPage))
const rangeText = computed(() => {
  const n = props.rows.length
  const a = (page.value - 1) * props.perPage + 1
  return `${a}–${Math.min(page.value * props.perPage, n)} dari ${n.toLocaleString('id-ID')} nasabah`
})
/** Nomor halaman: semua bila <= 7, selain itu 1 … (sekitar aktif) … akhir. */
const pages = computed<(number | '…')[]>(() => {
  const n = pageCount.value
  const p = page.value
  if (n <= 7) return Array.from({ length: n }, (_, i) => i + 1)
  const out: (number | '…')[] = [1]
  const a = Math.max(2, p - 1)
  const b = Math.min(n - 1, p + 1)
  if (a > 2) out.push('…')
  for (let i = a; i <= b; i++) out.push(i)
  if (b < n - 1) out.push('…')
  out.push(n)
  return out
})

const str = (v: unknown): string => (v == null ? '' : String(v).trim())
const n = (v: unknown): number => Number(v) || 0
const days = (r: Row): number => n(r.tgkhari)
/** Tingkat lewat jatuh tempo: <= 30 hari, 31–90, > 90. */
const tone = (r: Row): string => (days(r) > 90 ? 'bad' : days(r) > 30 ? 'warn' : '')
const kantor = (r: Row): string => props.kantorNama?.get(str(r.kdloc)) ?? `Kantor ${str(r.kdloc)}`
const produk = (r: Row): string => props.produkNama?.get(str(r.kdprd)) ?? str(r.kdprd)
/** Jangka waktu: jw + satuan kdjw (B = bulan, H = hari, T = tahun). */
const jangka = (r: Row): string => {
  const unit: Record<string, string> = { B: 'bulan', H: 'hari', T: 'tahun' }
  const jw = str(r.jw)
  if (!jw) return '–'
  return `${jw} ${unit[str(r.kdjw).toUpperCase()] ?? str(r.kdjw)}`.trim()
}
</script>

<template>
  <div class="dc">
    <template v-if="rows.length">
      <ul class="dc-grid">
        <li v-for="r in visible" :key="str(r.nokontrak)" class="dc-card">
          <header class="dc-head">
            <div class="dc-who">
              <b>{{ str(r.nama) }}</b>
              <small class="num">{{ str(r.nokontrak) }}</small>
            </div>
            <span class="dc-badge num" :class="tone(r)">{{ days(r) > 0 ? `Lewat ${days(r).toLocaleString('id-ID')} hari` : 'Hari ini' }}</span>
          </header>

          <dl class="dc-kv">
            <div><dt>Kantor</dt><dd>{{ kantor(r) }} <small class="num">{{ str(r.kdloc) }}</small></dd></div>
            <div><dt>Produk</dt><dd>{{ produk(r) }} <small class="num">{{ str(r.kdprd) }}</small></dd></div>
            <div><dt>Jatuh tempo</dt><dd class="num">{{ str(r.tglexp) || '–' }}</dd></div>
            <div><dt>Jangka waktu</dt><dd class="num">{{ jangka(r) }}</dd></div>
            <div><dt>Kolektibilitas</dt><dd class="num">Kol {{ str(r.colbaru) || '–' }}</dd></div>
            <div><dt>Margin</dt><dd class="num"><RpValue :value="Math.round(n(r.osmgnc))" /></dd></div>
          </dl>

          <footer class="dc-foot">
            <span>OS pokok</span>
            <b class="num"><RpValue :value="Math.round(n(r.osmdlc))" /></b>
          </footer>
        </li>
      </ul>

      <nav v-if="pageCount > 1" class="pby-pager dc-pager" aria-label="Halaman daftar nasabah">
        <button type="button" class="dc-step" :disabled="page <= 1" aria-label="Halaman sebelumnya" @click="page--">‹</button>
        <template v-for="(p, i) in pages" :key="`${p}-${i}`">
          <span v-if="p === '…'" class="dc-gap" aria-hidden="true">…</span>
          <button
            v-else type="button" class="dc-num num" :class="{ on: p === page }"
            :aria-current="p === page ? 'page' : undefined" :aria-label="`Halaman ${p}`" @click="page = p"
          >{{ p }}</button>
        </template>
        <button type="button" class="dc-step" :disabled="page >= pageCount" aria-label="Halaman berikutnya" @click="page++">›</button>
        <span class="dc-range num">{{ rangeText }}</span>
      </nav>
    </template>
    <p v-else class="muted">{{ empty }}</p>
  </div>
</template>

<style scoped>
.dc-grid {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.65rem;
}
@media (max-width: 1280px) { .dc-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 980px) { .dc-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 620px) { .dc-grid { grid-template-columns: minmax(0, 1fr); } }

.dc-card {
  display: flex;
  flex-direction: column;
  min-width: 0;
  border: 1px solid var(--border-strong);
  border-radius: 12px;
  background: var(--surface);
  padding: 0.75rem 0.85rem 0.7rem;
}
.dc-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 0.5rem; }
.dc-who { display: flex; flex-direction: column; min-width: 0; }
.dc-who b { font-size: var(--fs-sm); font-weight: 600; color: var(--ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dc-who small { font-size: 0.75rem; color: var(--muted); }
.dc-badge {
  flex: none;
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
  background: var(--surface-2);
  color: var(--muted-2, var(--muted));
}
.dc-badge.warn { background: var(--amber-bg); color: var(--amber); }
.dc-badge.bad { background: var(--red-bg); color: var(--red-dark); }

.dc-kv {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.45rem 0.75rem;
  margin: 0.7rem 0 0;
  padding-top: 0.6rem;
  border-top: 1px solid var(--border);
}
.dc-kv > div { min-width: 0; }
.dc-kv dt { font-size: 0.7rem; color: var(--muted); }
.dc-kv dd { margin: 0.05rem 0 0; font-size: 0.8125rem; font-weight: 500; color: var(--ink); overflow-wrap: anywhere; line-height: 1.3; }
.dc-kv dd small { font-size: 0.7rem; color: var(--muted); font-weight: 400; }

.dc-foot {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  margin-top: auto;
  padding: 0.55rem 0.65rem;
  border-radius: 8px;
  background: var(--surface-2);
}
.dc-kv { margin-bottom: 0.7rem; }
.dc-foot span { font-size: 0.75rem; color: var(--muted); }
.dc-foot b { font-size: var(--fs-md, 1rem); font-weight: 700; color: var(--ink); white-space: nowrap; }

/* Pager: ‹ 1 2 3 › + rentang */
.dc-pager { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem; margin-top: 0.9rem; }
.dc-pager .dc-num,
.dc-pager .dc-step {
  min-width: 34px;
  height: 34px;
  padding: 0 0.5rem;
  border: 1px solid var(--border-strong);
  border-radius: 8px;
  background: var(--surface);
  color: var(--ink);
  font: inherit;
  font-size: var(--fs-sm);
  cursor: pointer;
}
.dc-pager .dc-num:hover:not(.on),
.dc-pager .dc-step:hover:not(:disabled) { background: var(--surface-2); }
.dc-pager .dc-num.on { background: var(--primary); border-color: var(--primary); color: var(--on-primary, #fff); font-weight: 600; }
.dc-pager .dc-step:disabled { opacity: 0.35; cursor: default; }
.dc-pager button:focus-visible { outline: 2px solid var(--primary-ring, var(--primary)); outline-offset: 2px; }
.dc-gap { padding: 0 0.2rem; color: var(--muted); }
.dc-range { margin-left: auto; font-size: var(--fs-sm); color: var(--muted); }
@media (max-width: 620px) { .dc-range { margin-left: 0; width: 100%; } }
</style>
