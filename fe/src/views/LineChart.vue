<script lang="ts">
export interface LineSerie {
  key: string
  label: string
  color: string
  dash?: string
  values: (number | null)[]
}
</script>

<script setup lang="ts">
import { computed, ref, useId, watch } from 'vue'
import { formatRupiah } from '../api'

/* ==========================================================================
   LineChart: grafik garis SVG (tanpa lib), dipakai laporan DPK & Piutang.
   Konvensi: WARNA = kantor (konstant antar laporan), garis putus-putus =
   produk/golongan kedua (dash), titik bulat = nilai per bulan dengan label
   nilai terlihat di atas tiap titik (hover -> rupiah penuh).
   Null pada periode = garis dipisah (segmen putus), bukan dihubungi bohong.
   ========================================================================== */

const props = defineProps<{
  labels: string[]
  series: LineSerie[]
  aria?: string
}>()

const W = 1040, H = 276, PADL = 56, PADR = 16, TOP = 16, BASE = 226

/* Animasi gambar garis: clipPath kiri -> kanan (dari awal ke akhir bulan)
   saat data tampil. defs di-key agar re-mount saat data berganti -> animasi
   main ulang. ID unik per instans (banyak chart per halaman). */
const uid = useId()
const drawKey = ref(0)
watch(() => [props.labels, props.series], () => { drawKey.value += 1 })

const maxVal = computed(() => {
  let m = 0
  for (const s of props.series) for (const v of s.values) if (v != null && v > m) m = v
  return m || 1
})

const trim = (v: number): string => v.toFixed(v < 10 ? 1 : 0)
const fmtAxis = (v: number): string => {
  if (v >= 1e12) return `${trim(v / 1e12)}T`
  if (v >= 1e9) return `${trim(v / 1e9)}M`
  if (v >= 1e6) return `${trim(v / 1e6)}Jt`
  if (v >= 1e3) return `${trim(v / 1e3)}rb`
  return String(Math.round(v))
}

const ticks = computed(() => {
  const mx = maxVal.value
  const plotH = BASE - TOP
  // g=0 = garis dasar (bawah) -> label 0; g=4 (atas) -> label maks.
  // (Dulu kebalik: dasar dilabeli maks, puncak dilabeli 0.)
  return [0, 1, 2, 3, 4].map((g) => ({
    y: BASE - (g * plotH) / 4,
    label: fmtAxis((mx * g) / 4),
  }))
})

const xAt = (i: number): number =>
  PADL + (i * (W - PADL - PADR)) / Math.max(1, props.labels.length - 1)
const yAt = (v: number): number => BASE - (v / maxVal.value) * (BASE - TOP)

interface Drawn {
  segs: string[] // polyline points per segmen (null memutus garis)
  pts: { x: number; y: number; v: number; title: string }[]
}

const drawn = computed<Drawn[]>(() =>
  props.series.map((s) => {
    const segs: string[] = []
    let cur: string[] = []
    const pts: Drawn['pts'] = []
    s.values.forEach((v, i) => {
      if (v == null || i >= props.labels.length) {
        if (cur.length > 1) segs.push(cur.join(' '))
        cur = []
        return
      }
      const x = xAt(i), y = yAt(v)
      cur.push(`${x},${y}`)
      pts.push({ x, y, v, title: `${s.label} · ${props.labels[i]}: ${formatRupiah(v)}` })
    })
    if (cur.length > 1) segs.push(cur.join(' '))
    return { segs, pts }
  }),
)
</script>

<template>
  <div>
    <div class="chart-scroll">
      <div class="chart-wrap lc" :style="{ width: `max(100%, ${W}px)` }">
        <svg :viewBox="`0 0 ${W} ${H}`" role="img" :aria-label="aria ?? 'Grafik garis laporan'">
          <!-- Clip animasi draw (kiri -> kanan); key = drawKey -> main ulang saat data ganti -->
          <defs :key="drawKey">
            <clipPath :id="`lcdraw-${uid}`" clipPathUnits="userSpaceOnUse">
              <rect
                class="lc-clip-rect"
                x="0" y="0" :width="W" :height="H"
                :style="{ '--lc-w': `${W}px` }"
              />
            </clipPath>
          </defs>
          <g v-for="t in ticks" :key="t.y">
            <line :x1="PADL" :y1="t.y" :x2="W - PADR" :y2="t.y" stroke="rgba(10,25,47,0.10)" stroke-width="1" />
            <text :x="PADL - 8" :y="t.y + 3.5" text-anchor="end" font-size="10" fill="#475569">{{ t.label }}</text>
          </g>
          <g
            v-for="(s, si) in series"
            :key="s.key"
            :clip-path="`url(#lcdraw-${uid})`"
          >
            <polyline
              v-for="(seg, gi) in drawn[si]?.segs ?? []"
              :key="gi"
              :points="seg"
              fill="none"
              :stroke="s.color"
              stroke-width="2.2"
              :stroke-dasharray="s.dash"
              stroke-linejoin="round"
              stroke-linecap="round"
            />
            <circle
              v-for="(p, pi) in drawn[si]?.pts ?? []"
              :key="pi"
              :cx="p.x" :cy="p.y" r="3.4"
              :fill="s.color" stroke="#fff" stroke-width="1.2"
            >
              <title>{{ p.title }}</title>
            </circle>
            <text
              v-for="(p, pi) in drawn[si]?.pts ?? []"
              :key="`v${pi}`"
              :x="p.x" :y="p.y - 7" text-anchor="middle"
              font-size="9" font-weight="700" fill="#191c1e"
            >{{ fmtAxis(p.v) }}</text>
          </g>
          <line :x1="PADL" :y1="BASE" :x2="W - PADR" :y2="BASE" stroke="rgba(10,25,47,0.35)" stroke-width="1" />
          <text
            v-for="(lb, i) in labels"
            :key="lb + i"
            :x="xAt(i)" :y="BASE + 20" text-anchor="middle" font-size="10" fill="#475569"
          >{{ lb }}</text>
        </svg>
      </div>
    </div>
    <ul class="lc-legend">
      <li v-for="s in series" :key="s.key">
        <svg class="lc-key" width="20" height="8" aria-hidden="true">
          <line x1="0" y1="4" x2="20" y2="4" :stroke="s.color" stroke-width="2.5" :stroke-dasharray="s.dash" />
        </svg>
        {{ s.label }}
      </li>
    </ul>
  </div>
</template>

<style scoped>
.chart-scroll {
  overflow-x: auto;
}
/* Animasi draw garis: clip rect melebar 0 -> lebar plot (kiri ke kanan,
   Jan -> Des). Jika browser tak dukung animasi width, rect tetap W (attribute
   default) -> chart tampil penuh tanpa animasi (gagal aman). */
.lc-clip-rect {
  animation: lc-draw 1.6s cubic-bezier(0.22, 1, 0.36, 1) both;
}
@keyframes lc-draw {
  from { width: 0; }
  to { width: var(--lc-w); }
}
.lc-key {
  flex: 0 0 auto;
}
/* Legend = chip berbingkai (bukan teks mentah). */
.lc-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin: 0.6rem 0 0;
  padding: 0;
  list-style: none;
  font-size: 0.8rem;
}
.lc-legend li {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.25rem 0.6rem;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  background: #f8fafc;
  color: #334155;
  font-weight: 500;
}
</style>
