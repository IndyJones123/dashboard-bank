<script lang="ts">
export interface DetailCol {
  key: string
  label: string
  right?: boolean
}
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import RpValue from './RpValue.vue'

/* ==========================================================================
   DetailTable: tabel terperinci utk laporan DPK (2) & Piutang (3).
   - PAGINATION (default 10 baris/halaman, footer selalu tampil).
   - SEMUA kolom 1 baris (nowrap) -> tabel dilebar gulir kiri-kanan sendiri,
     tidak pernah wrap nilai ke baris ke-2/3.
   - Sel angka: RpValue (> 11 digit ringkas M + tombol nilai lengkap).
   ========================================================================== */

const props = withDefaults(
  defineProps<{ cols: DetailCol[]; rows: Record<string, unknown>[]; perPage?: number }>(),
  { perPage: 10 },
)

const page = ref(1)
/** Rows berubah (ganti tahun/kantor) -> jangan biarkan halaman nge-flip kosong. */
watch(
  () => props.rows.length,
  (n) => {
    const max = Math.max(1, Math.ceil(n / props.perPage))
    if (page.value > max) page.value = max
  },
)

const pageCount = computed(() => Math.max(1, Math.ceil(props.rows.length / props.perPage)))
const paged = computed(() =>
  props.rows.slice((page.value - 1) * props.perPage, page.value * props.perPage),
)
const range = computed(() => {
  const n = props.rows.length
  if (!n) return '0 baris'
  const a = (page.value - 1) * props.perPage + 1
  const b = Math.min(page.value * props.perPage, n)
  return `${a}–${b} dari ${n} baris`
})

const text = (v: unknown): string => (v == null ? '–' : String(v))
</script>

<template>
  <div>
    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th v-for="c in cols" :key="c.key" :class="{ 'ta-r': c.right }">{{ c.label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(r, ri) in paged" :key="String(r.id ?? ri)">
            <td
              v-for="c in cols"
              :key="c.key"
              :class="{ 'ta-r': c.right }"
            ><RpValue v-if="typeof r[c.key] === 'number'" :value="r[c.key] as number" /><template v-else>{{ text(r[c.key]) }}</template></td>
          </tr>
          <tr v-if="!paged.length">
            <td :colspan="cols.length" class="muted">Tidak ada baris.</td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="pager">
      <button
        type="button" :disabled="page <= 1"
        aria-label="Halaman sebelumnya" @click="page--"
      >‹</button>
      <span class="pg-info">Halaman {{ page }} dari {{ pageCount }}, {{ range }}</span>
      <button
        type="button" :disabled="page >= pageCount"
        aria-label="Halaman berikutnya" @click="page++"
      >›</button>
    </div>
  </div>
</template>

<style scoped>
/* Aturan inti: isi sel TIDAK BOLEH wrap: 1 baris, sisanya gulir horizontal. */
table th,
table td {
  white-space: nowrap;
}
.pager {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  margin-top: 0.55rem;
  font-size: var(--fs-sm);
  color: var(--muted);
}
.pager button {
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-strong);
  border-radius: 50%;
  background: var(--surface);
  color: var(--ink);
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}
.pager button:hover:not(:disabled) { background: var(--surface-2); }
.pager button:disabled { opacity: 0.4; cursor: default; }
.pg-info { font-variant-numeric: tabular-nums; }
</style>
