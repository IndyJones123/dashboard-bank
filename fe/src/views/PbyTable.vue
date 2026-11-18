<script lang="ts">
export type PbyFmt = 'rp' | 'int' | 'pct' | 'text'

export interface PbyCol {
  key: string
  label: string
  fmt?: PbyFmt
  /** Kolom kecil di bawah teks utama (mis. kode kantor di bawah nama). */
  sub?: string
  /** Dijumlahkan di baris subtotal/total (default: rp & int). */
  sum?: boolean
  /** Judul grup header (kolom berurutan dgn grup sama digabung). */
  group?: string
}
</script>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'

/* ==========================================================================
   PbyTable: tabel laporan Pembiayaan. Nilai apa adanya dari query, hanya
   diformat (Rupiah penuh tanpa desimal, NOA bilangan bulat, NPF 2 desimal).
   - subtotalBy: sisipkan subtotal tiap pergantian nilai kolom itu (urutan
     baris dari ORDER BY query, tidak diurut ulang)
   - total: baris jumlah di footer; `totalOverride` utk kolom turunan (NPF %)
   - perPage > 0: pagination (daftar nasabah)
   ========================================================================== */

const props = withDefaults(
  defineProps<{
    cols: PbyCol[]
    rows: Record<string, unknown>[]
    subtotalBy?: string
    subtotalLabel?: (row: Record<string, unknown>) => string
    total?: boolean
    totalOverride?: (rows: Record<string, unknown>[]) => Record<string, unknown>
    perPage?: number
    empty?: string
  }>(),
  { perPage: 0, total: true, empty: 'Tidak ada data.' },
)

const summable = (c: PbyCol): boolean => c.sum ?? (c.fmt === 'rp' || c.fmt === 'int')

function sumRows(src: Record<string, unknown>[]): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const c of props.cols) {
    if (!summable(c)) continue
    out[c.key] = src.reduce((s, r) => s + (Number(r[c.key]) || 0), 0)
  }
  return { ...out, ...(props.totalOverride?.(src) ?? {}) }
}

interface Line {
  kind: 'row' | 'sub'
  key: string
  data: Record<string, unknown>
  label?: string
}

const page = ref(1)
watch(() => props.rows, () => { page.value = 1 })
const pageCount = computed(() =>
  props.perPage > 0 ? Math.max(1, Math.ceil(props.rows.length / props.perPage)) : 1,
)
const visible = computed(() =>
  props.perPage > 0
    ? props.rows.slice((page.value - 1) * props.perPage, page.value * props.perPage)
    : props.rows,
)

const lines = computed<Line[]>(() => {
  const by = props.subtotalBy
  const src = visible.value
  if (!by) return src.map((r, i) => ({ kind: 'row', key: `r${i}`, data: r }))
  const out: Line[] = []
  let grp: Record<string, unknown>[] = []
  const flush = (): void => {
    if (grp.length < 2) { grp = []; return }  // subtotal 1 baris = duplikat, lewati
    out.push({
      kind: 'sub', key: `s${out.length}`, data: sumRows(grp),
      label: props.subtotalLabel?.(grp[0]) ?? `Subtotal ${String(grp[0][by] ?? '')}`,
    })
    grp = []
  }
  src.forEach((r, i) => {
    if (grp.length && grp[0][by] !== r[by]) flush()
    out.push({ kind: 'row', key: `r${i}`, data: r })
    grp.push(r)
  })
  flush()
  return out
})

const totalRow = computed(() => (props.total && props.rows.length ? sumRows(props.rows) : null))

const groups = computed(() => {
  if (!props.cols.some((c) => c.group)) return null
  const out: { label: string; span: number }[] = []
  for (const c of props.cols) {
    const g = c.group ?? ''
    const last = out[out.length - 1]
    if (last && last.label === g && g) last.span += 1
    else out.push({ label: g, span: 1 })
  }
  return out
})

function fmt(v: unknown, f: PbyFmt = 'text'): string {
  if (v === null || v === undefined || v === '') return '–'
  if (f === 'text') return String(v)
  const n = Number(v)
  if (Number.isNaN(n)) return String(v)
  if (f === 'pct') return `${n.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`
  return Math.round(n).toLocaleString('id-ID')
}
const isNum = (c: PbyCol): boolean => !!c.fmt && c.fmt !== 'text'
const rangeText = computed(() => {
  const n = props.rows.length
  if (!n) return '0 baris'
  const a = (page.value - 1) * props.perPage + 1
  return `${a}–${Math.min(page.value * props.perPage, n)} dari ${n.toLocaleString('id-ID')} baris`
})
</script>

<template>
  <div>
    <div class="table-scroll pby-table">
      <table>
        <thead>
          <tr v-if="groups" class="grp">
            <th
              v-for="(g, i) in groups" :key="i" :colspan="g.span"
              :class="{ 'ta-c': g.label, blank: !g.label }"
            >{{ g.label }}</th>
          </tr>
          <tr>
            <th v-for="c in cols" :key="c.key" :class="{ 'ta-r': isNum(c) }">{{ c.label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="ln in lines" :key="ln.key" :class="{ subtotal: ln.kind === 'sub' }">
            <td v-for="(c, ci) in cols" :key="c.key" :class="{ 'ta-r': isNum(c) }">
              <template v-if="ln.kind === 'sub'">
                <template v-if="ci === 0">{{ ln.label }}</template>
                <template v-else-if="ln.data[c.key] !== undefined">{{ fmt(ln.data[c.key], c.fmt) }}</template>
              </template>
              <template v-else>
                {{ fmt(ln.data[c.key], c.fmt) }}
                <span v-if="c.sub && ln.data[c.sub] != null" class="cell-sub">{{ ln.data[c.sub] }}</span>
              </template>
            </td>
          </tr>
          <tr v-if="!rows.length">
            <td :colspan="cols.length" class="muted">{{ empty }}</td>
          </tr>
        </tbody>
        <tfoot v-if="totalRow">
          <tr>
            <td v-for="(c, ci) in cols" :key="c.key" :class="{ 'ta-r': isNum(c) }">
              <template v-if="ci === 0">Total</template>
              <template v-else-if="totalRow[c.key] !== undefined">{{ fmt(totalRow[c.key], c.fmt) }}</template>
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
    <div v-if="perPage > 0 && rows.length > perPage" class="pby-pager">
      <button type="button" :disabled="page <= 1" aria-label="Halaman sebelumnya" @click="page--">‹</button>
      <span class="num">Halaman {{ page }} dari {{ pageCount }}, {{ rangeText }}</span>
      <button type="button" :disabled="page >= pageCount" aria-label="Halaman berikutnya" @click="page++">›</button>
    </div>
  </div>
</template>

<style scoped>
.pby-table th,
.pby-table td { white-space: nowrap; }
.pby-table td.ta-r { font-variant-numeric: tabular-nums; }
/* Grup header: label kecil di atas kolomnya, garis tipis penanda rentang */
.pby-table .grp th { border-bottom: 0; padding-bottom: 0.15rem; color: var(--muted-2); font-weight: 600; }
.pby-table .grp th.ta-c { box-shadow: inset 0 -1px 0 var(--ink-16); }
.pby-table .grp th.blank { box-shadow: none; }
.pby-table tr.subtotal td {
  background: var(--ink-4);
  font-weight: 600;
  color: var(--ink);
}
.pby-table tfoot td {
  background: var(--surface);
  border-top: 1px solid var(--ink);
  border-bottom: 0;
  font-weight: 600;
  color: var(--ink);
}
.pby-table tfoot td:first-child { background: var(--surface); }
.pby-table tr.subtotal td:first-child { background: color-mix(in srgb, var(--surface) 96%, var(--ink)); }
.pby-pager {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.85rem;
  font-size: var(--fs-sm);
  color: var(--muted);
}
.pby-pager button {
  width: 36px;
  height: 36px;
  border: 1px solid var(--border-strong);
  border-radius: 50%;
  background: var(--surface);
  color: var(--ink);
  font-size: 1.05rem;
  cursor: pointer;
}
.pby-pager button:hover:not(:disabled) { background: var(--surface-2); }
.pby-pager button:disabled { opacity: 0.35; cursor: default; }
</style>
