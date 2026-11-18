<script lang="ts">
export interface StackSeg {
  key: string
  label: string
  value: number
  color: string
  /** Teks kecil di legenda (mis. jumlah NOA). */
  note?: string
}
</script>

<script setup lang="ts">
import { computed } from 'vue'
import { formatRupiah } from '../api'
import { formatRpSingkat } from '../report-helpers'

/* Bar komposisi 100% (kolektibilitas / bucket DPD) + legenda nilai & porsi.
   Hanya menjumlahkan kolom hasil query; tidak ada angka lain yg dibuat. */

const props = defineProps<{ segs: StackSeg[]; label: string }>()
const total = computed(() => props.segs.reduce((s, x) => s + (x.value > 0 ? x.value : 0), 0))
const pct = (v: number): number => (total.value > 0 && v > 0 ? (v / total.value) * 100 : 0)
const pctText = (v: number): string =>
  `${pct(v).toLocaleString('id-ID', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`
</script>

<template>
  <div class="stack">
    <div class="stack-bar" role="img" :aria-label="label">
      <span
        v-for="s in segs" v-show="pct(s.value) > 0" :key="s.key"
        :style="{ width: `${pct(s.value)}%`, background: s.color }"
        :title="`${s.label}: ${formatRupiah(s.value)} (${pctText(s.value)})`"
      />
    </div>
    <ul class="stack-legend">
      <li v-for="s in segs" :key="s.key">
        <span class="sw" :style="{ background: s.color }" aria-hidden="true" />
        <span class="lbl">{{ s.label }}<small v-if="s.note">{{ s.note }}</small></span>
        <strong class="num" :title="formatRupiah(s.value)">{{ formatRpSingkat(s.value) }}</strong>
        <span class="pc num">{{ pctText(s.value) }}</span>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.stack { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1rem; }
.stack-bar {
  display: flex;
  height: 14px;
  border-radius: 999px;
  overflow: hidden;
  background: var(--surface-2);
}
.stack-bar span { display: block; height: 100%; min-width: 2px; }
.stack-bar span + span { box-shadow: inset 2px 0 0 var(--surface); }
.stack-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 0.6rem 1.5rem;
}
.stack-legend li {
  display: grid;
  grid-template-columns: 10px minmax(0, 1fr) auto;
  column-gap: 0.5rem;
  row-gap: 0.1rem;
  align-items: baseline;
}
.sw { width: 10px; height: 10px; border-radius: 3px; align-self: center; }
.lbl { grid-column: 2 / span 2; font-size: var(--fs-sm); font-weight: 600; color: var(--muted-2); }
.lbl small { font-weight: 400; color: var(--muted); margin-left: 0.35rem; }
.stack-legend strong { grid-column: 2; font-size: var(--fs-base); color: var(--ink); }
.pc { grid-column: 3; font-size: var(--fs-sm); color: var(--muted); }
</style>
