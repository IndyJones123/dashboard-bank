<script lang="ts">
export interface LineSerie {
  key: string
  label: string
  color: string
  dash?: string
  values: (number | null)[]
}

/* Elemen .lc-host -> instans chart. Dipakai Cinematic utk menyalin grafik
   sbg gambar (cloneNode tidak menyalin isi canvas). */
export const lineChartByEl = new WeakMap<HTMLElement, IChartApi>()
</script>

<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import {
  AreaSeries,
  ColorType,
  LineSeries,
  LineStyle,
  createChart,
  type IChartApi,
  type ISeriesApi,
  type MouseEventParams,
  type SeriesType,
  type Time,
} from 'lightweight-charts'
import { formatRupiah } from '../api'

/* ==========================================================================
   LineChart: grafik garis per kantor memakai TradingView Lightweight Charts.
   - Sumbu waktu = indeks periode (labels), tiap periode 1 "hari" dummy.
   - Seri null -> titik kosong (garis putus, bukan diisi nilai palsu).
   - Chip kantor di bawah: tampil/sembunyi seri; skala ikut seri yg tampil.
   - Tooltip saat kursor: nama kantor + nilai rupiah penuh.
   - Seri tunggal non-dash: area di bawah garis.
   ========================================================================== */

const props = withDefaults(
  defineProps<{
    labels: string[]
    series: LineSerie[]
    aria?: string
    /** false = tanpa legenda/chip di bawah. Default true (boolean tanpa default = false di Vue). */
    legend?: boolean
  }>(),
  { legend: true },
)
const showLegend = computed(() => props.legend)

const DAY = 86400
const host = ref<HTMLDivElement | null>(null)
const tip = ref<{ x: number; y: number; period: string; rows: { label: string; color: string; value: string }[] } | null>(null)
const tipEl = ref<HTMLDivElement | null>(null)
/** Posisi pop-up: sisi kanan kursor bila muat, kalau tidak sisi kiri (diukur, bukan ditebak). */
const tipLeft = ref(0)

/* Seri yg disembunyikan (chip). Minimal 1 seri tetap tampil. */
const off = ref<string[]>([])
const vis = computed<LineSerie[]>(() => props.series.filter((s) => !off.value.includes(s.key)))
function toggleSeries(key: string): void {
  if (off.value.includes(key)) off.value = off.value.filter((k) => k !== key)
  else if (vis.value.length > 1) off.value = [...off.value, key]
}
const selectable = computed(() => props.series.length > 1)

/* Format sumbu: >= 1 miliar selalu M (tanpa T), pemisah ribuan id-ID */
const trim = (v: number): string => v.toFixed(v < 10 ? 1 : 0)
function fmtAxis(v: number): string {
  if (v >= 1e9) return `${(v / 1e9).toLocaleString('id-ID', { maximumFractionDigits: v < 1e10 ? 1 : 0 })}M`
  if (v >= 1e6) return `${trim(v / 1e6)}Jt`
  if (v >= 1e3) return `${trim(v / 1e3)}rb`
  return String(Math.round(v))
}

const timeOf = (i: number): Time => ((i + 1) * DAY) as Time
const idxOf = (t: unknown): number => Math.round(Number(t) / DAY) - 1

let chart: IChartApi | null = null
let seriesMap: { s: ISeriesApi<SeriesType>; meta: LineSerie }[] = []

function themeColor(name: string, fallback: string): string {
  const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  return v || fallback
}

function build(): void {
  if (!host.value) return
  if (!chart) {
    chart = createChart(host.value, {
      autoSize: true,
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: themeColor('--muted', '#5d6963'),
        fontFamily: getComputedStyle(document.body).fontFamily,
        fontSize: 12,
        attributionLogo: false,
      },
      grid: {
        vertLines: { visible: false },
        horzLines: { color: themeColor('--border', 'rgba(21,32,27,0.07)') },
      },
      rightPriceScale: { visible: false },
      leftPriceScale: { visible: true, borderVisible: false },
      timeScale: {
        borderVisible: false,
        fixLeftEdge: true,
        fixRightEdge: true,
        tickMarkFormatter: (t: Time) => props.labels[idxOf(t)] ?? '',
      },
      crosshair: { vertLine: { labelVisible: false }, horzLine: { visible: false, labelVisible: false } },
      handleScroll: false,
      handleScale: false,
    })
    chart.subscribeCrosshairMove(onMove)
    if (host.value) lineChartByEl.set(host.value, chart)
  }
  // Hapus seri lama, buat ulang sesuai chip & data terbaru
  for (const m of seriesMap) chart.removeSeries(m.s)
  seriesMap = []
  const single = vis.value.length === 1 && !vis.value[0].dash
  for (const meta of vis.value) {
    const common = {
      priceFormat: { type: 'custom' as const, formatter: (v: number) => fmtAxis(v), minMove: 1 },
      lineWidth: 2 as const,
      lineStyle: meta.dash ? LineStyle.Dashed : LineStyle.Solid,
      crosshairMarkerRadius: 4,
      lastValueVisible: false,
      priceLineVisible: false,
      color: meta.color,
      lineColor: meta.color,
    }
    const s = single
      ? chart.addSeries(AreaSeries, {
          ...common,
          topColor: `${meta.color}2e`,
          bottomColor: `${meta.color}05`,
        })
      : chart.addSeries(LineSeries, common)
    // Null -> whitespace (titik kosong): garis terputus, tidak diisi
    s.setData(
      meta.values.map((v, i) => (v == null ? { time: timeOf(i) } : { time: timeOf(i), value: v })) as never,
    )
    seriesMap.push({ s: s as ISeriesApi<SeriesType>, meta })
  }
  chart.timeScale().fitContent()
}

function onMove(p: MouseEventParams<Time>): void {
  if (!p.time || !p.point || !host.value) {
    tip.value = null
    return
  }
  const i = idxOf(p.time)
  const rows = seriesMap
    .map(({ s, meta }) => {
      const d = p.seriesData.get(s) as { value?: number } | undefined
      if (d?.value == null) return null
      return { label: meta.label, color: meta.color, value: formatRupiah(d.value), v: d.value }
    })
    .filter((r): r is { label: string; color: string; value: string; v: number } => r !== null)
    .sort((a, b) => b.v - a.v)
    .map(({ v: _v, ...r }) => r)
  if (!rows.length) {
    tip.value = null
    return
  }
  tip.value = { x: p.point.x, y: p.point.y, period: props.labels[i] ?? '', rows }
  void nextTick(() => {
    const w = tipEl.value?.offsetWidth ?? 0
    const hw = host.value?.clientWidth ?? 0
    const right = p.point!.x + 14
    tipLeft.value = right + w <= hw ? right : Math.max(0, p.point!.x - 14 - w)
  })
}

/* Pop-up selalu di dalam area grafik (atas), disisi kursor; tidak terpotong */
const tipStyle = computed(() => ({ left: `${tipLeft.value}px`, top: '6px' }))

onMounted(async () => {
  await nextTick()
  build()
})
watch(
  () => [props.labels, vis.value, props.series],
  () => build(),
  { deep: true },
)
onBeforeUnmount(() => {
  chart?.remove()
  chart = null
  seriesMap = []
})
</script>

<template>
  <div>
    <div class="chart-scroll">
      <div class="lc-host-wrap">
        <div
          ref="host"
          class="lc-host"
          role="img"
          :aria-label="aria ?? 'Grafik garis laporan'"
        />
        <div v-if="tip" ref="tipEl" class="lc-tip" :class="{ wide: tip.rows.length > 4 }" :style="tipStyle" role="status">
          <small>{{ tip.period }}</small>
          <span v-for="r in tip.rows" :key="r.label" class="lc-tip-row">
            <i :style="{ background: r.color }" aria-hidden="true" />
            {{ r.label }} <strong>{{ r.value }}</strong>
          </span>
        </div>
      </div>
    </div>
    <!-- Kaki chart: legend chip (bisa dipilih bila >1 kantor) -->
    <div v-if="showLegend" class="lc-foot">
      <ul class="lc-legend" :aria-label="selectable ? 'Pilih kantor yang ditampilkan' : undefined">
        <li v-for="s in props.series" :key="s.key">
          <button
            v-if="selectable"
            type="button"
            class="lc-chip"
            :class="{ off: off.includes(s.key) }"
            :aria-pressed="!off.includes(s.key)"
            @click="toggleSeries(s.key)"
          >
            <i class="lc-dot" :class="{ dash: s.dash }" :style="s.dash ? { color: s.color } : { background: s.color }" aria-hidden="true" />
            {{ s.label }}
          </button>
          <template v-else>
            <i class="lc-dot" :class="{ dash: s.dash }" :style="s.dash ? { color: s.color } : { background: s.color }" aria-hidden="true" />
            {{ s.label }}
          </template>
        </li>
        <li v-if="selectable && off.length">
          <button type="button" class="lc-chip all" @click="off = []">Tampilkan semua</button>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.chart-scroll { overflow: visible; }
.lc-host-wrap { position: relative; width: 100%; height: 320px; }
.lc-host { position: absolute; inset: 0; }
.lc-tip {
  position: absolute; z-index: 2; pointer-events: none;
  display: grid; gap: 0.15rem; width: max-content; max-width: 100%;
  padding: 0.45rem 0.6rem; border-radius: 8px;
  background: var(--ink); color: var(--bg);
  font-size: var(--fs-sm); box-shadow: 0 8px 20px rgba(0, 0, 0, 0.2);
}
.lc-tip.wide { grid-template-columns: auto auto; column-gap: 1.1rem; }
.lc-tip.wide small { grid-column: 1 / -1; }
.lc-tip small { font-size: 0.75rem; opacity: 0.75; }
.lc-tip-row { display: flex; align-items: center; gap: 0.4rem; white-space: nowrap; }
.lc-tip-row strong { margin-left: auto; padding-left: 0.6rem; font-variant-numeric: tabular-nums; }
.lc-tip-row { min-width: 0; }
.lc-tip-row i { width: 8px; height: 8px; border-radius: 50%; flex: none; }

/* Kaki: legend chip; wrap saat sempit. */
.lc-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  flex-wrap: wrap;
  margin-top: 0.6rem;
}
.lc-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem 0.5rem;
  margin: 0;
  padding: 0;
  list-style: none;
  font-size: var(--fs-sm);
  color: var(--muted-2);
}
.lc-legend li {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 500;
}
.lc-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; flex: none; }
/* Seri putus-putus (mis. target): ikon garis putus, bukan titik */
.lc-dot.dash { width: 16px; height: 0; border-radius: 0; border-top: 2px dashed currentColor; }
/* Chip kantor: tap/klik untuk tampil/sembunyi */
.lc-chip {
  display: inline-flex; align-items: center; gap: 0.4rem;
  min-height: 34px; padding: 0.25rem 0.7rem;
  border: 1px solid var(--border-strong); border-radius: 999px;
  background: var(--surface); color: var(--ink);
  font: inherit; font-size: var(--fs-sm); font-weight: 500; cursor: pointer;
  transition: background 0.15s ease, opacity 0.15s ease;
}
.lc-chip:hover { background: var(--surface-2); }
.lc-chip:focus-visible { outline: 2px solid var(--primary-ring); outline-offset: 2px; }
.lc-chip.off { opacity: 0.45; text-decoration: line-through; }
.lc-chip.all { color: var(--primary); border-color: var(--primary-40); }
</style>
