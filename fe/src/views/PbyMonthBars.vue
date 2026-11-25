<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { formatRupiah } from '../api'
import { shortMonth } from '../report-helpers'

/* Grafik batang bulanan BERDAMPINGAN: tiap bulan = 1 batang per produk,
   tinggi batang = nilai produk itu (skala dari nol). SVG digambar 1 unit = 1px
   (lebar diukur ResizeObserver) supaya teks sumbu sama ukurannya dgn teks halaman. */
export interface MonthSeries { key: string; label: string; color: string; values: number[] }

const props = withDefaults(defineProps<{
  series: MonthSeries[]
  /** Jumlah bulan yg sudah ada datanya (sisanya kosong). */
  months?: number
  /** Bulan (1..12) yg ditebalkan labelnya. */
  highlight?: number
  /** Label di atas tiap bulan (mis. NPF %); default = total nilai bulan itu. */
  tops?: (string | null)[]
  label: string
}>(), { months: 12, highlight: 0, tops: undefined })

const box = ref<HTMLElement | null>(null)
const W = ref(720)
let ro: ResizeObserver | null = null
onMounted(() => {
  if (!box.value) return
  W.value = box.value.clientWidth || 720
  ro = new ResizeObserver(([e]) => { W.value = Math.max(320, Math.round(e.contentRect.width)) })
  ro.observe(box.value)
})
onBeforeUnmount(() => ro?.disconnect())

const H = 260
const PL = 56
const PR = 8
const TOP = 30
const BASE = H - 28

function short(v: number): string {
  const s = Math.abs(v)
  const [d, u] = s >= 1e9 ? [1e9, ' M'] : s >= 1e6 ? [1e6, ' Jt'] : s >= 1e3 ? [1e3, ' rb'] : [1, '']
  return `${(s / d).toLocaleString('id-ID', { maximumFractionDigits: d === 1 ? 0 : 1 })}${u}`
}

const max = computed(() => {
  let m = 0
  for (const s of props.series) for (let i = 0; i < props.months; i++) m = Math.max(m, s.values[i] ?? 0)
  return m || 1
})
const slot = computed(() => (W.value - PL - PR) / 12)
const ticks = computed(() => [0, 1, 2, 3, 4].map((g) => ({
  y: TOP + ((BASE - TOP) * g) / 4,
  text: g === 4 ? '0' : short((max.value * (4 - g)) / 4),
})))

const groups = computed(() => Array.from({ length: 12 }, (_, i) => {
  const x = PL + i * slot.value
  const vals = i < props.months
    ? props.series.map((s) => ({ ...s, v: s.values[i] ?? 0 })).filter((s) => s.v > 0)
    : []
  const n = vals.length
  const group = slot.value * 0.76
  const gap = n > 1 ? Math.min(3, group * 0.06) : 0
  const w = n ? Math.min(22, (group - gap * (n - 1)) / n) : 0
  const used = n * w + gap * Math.max(0, n - 1)
  const x0 = x + (slot.value - used) / 2
  const bars = vals.map((s, j) => {
    const h = Math.max(1.5, (s.v / max.value) * (BASE - TOP))
    return { key: s.key, label: s.label, color: s.color, v: s.v, x: x0 + j * (w + gap), y: BASE - h, w, h }
  })
  const total = vals.reduce((t, s) => t + s.v, 0)
  return {
    i, cx: x + slot.value / 2, bars, total,
    top: bars.length ? Math.min(...bars.map((b) => b.y)) : BASE,
    text: props.tops ? (props.tops[i] ?? '') : total ? short(total) : '',
    name: shortMonth(String(i + 1)),
  }
}))
</script>

<template>
  <div>
    <ul class="mb-legend" aria-label="Warna produk">
      <li v-for="s in series" :key="s.key"><i :style="{ background: s.color }" aria-hidden="true" />{{ s.label }}</li>
    </ul>
    <div ref="box" class="mb-box">
      <svg :viewBox="`0 0 ${W} ${H}`" :width="W" :height="H" role="img" :aria-label="label">
        <g v-for="t in ticks" :key="t.y">
          <line class="l-grid" :x1="PL" :x2="W - PR" :y1="t.y" :y2="t.y" />
          <text class="mb-axis" :x="PL - 8" :y="t.y + 4" text-anchor="end">{{ t.text }}</text>
        </g>
        <line class="l-base" :x1="PL" :x2="W - PR" :y1="BASE" :y2="BASE" />
        <g v-for="g in groups" :key="g.i">
          <g class="svg-bar" :style="{ '--i': g.i }">
            <rect v-for="b in g.bars" :key="b.key" :x="b.x" :y="b.y" :width="b.w" :height="b.h" :fill="b.color" rx="2">
              <title>{{ g.name }} · {{ b.label }}: {{ formatRupiah(Math.round(b.v)) }}</title>
            </rect>
          </g>
          <text v-if="g.bars.length && g.text" class="mb-val svg-bar-val" :x="g.cx" :y="g.top - 7" text-anchor="middle" :style="{ '--i': g.i }">{{ g.text }}</text>
          <text
            class="mb-axis svg-bar-x" :class="{ on: g.i + 1 === highlight }"
            :x="g.cx" :y="H - 8" text-anchor="middle" :style="{ '--i': g.i }"
          >{{ g.name }}</text>
        </g>
      </svg>
    </div>
  </div>
</template>

<style scoped>
.mb-legend {
  display: flex; flex-wrap: wrap; gap: 0.35rem 1.1rem;
  margin: 0 0 0.75rem; padding: 0; list-style: none;
  font-size: var(--fs-sm); color: var(--muted);
}
.mb-legend li { display: inline-flex; align-items: center; gap: 0.45rem; }
.mb-legend i { width: 10px; height: 10px; border-radius: 3px; flex: none; }
.mb-box { width: 100%; overflow: hidden; }
.mb-box svg { display: block; font-variant-numeric: tabular-nums; }
.mb-axis { fill: var(--muted); font-size: 12px; }
.mb-axis.on { fill: var(--ink); font-weight: 600; }
.mb-val { fill: var(--ink); font-size: 11px; font-weight: 600; }
</style>
