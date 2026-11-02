<script setup lang="ts">
import { computed, useId } from 'vue'

/* ==========================================================================
   Sparkline: garis tren mini utk kartu metrik (gaya fitlink.id).
   ATURAN: hanya dipakai bila deret data ASLI tersedia (mis. jumlah saldo
   per periode dari baris yg sama dgn grafik/tabel). Tanpa sumbu/label :
   nilai penuh tetap di grafik utama & tabel. Tanpa data (<2 titik) = kosong.
   ========================================================================== */
const props = defineProps<{
  values: (number | null)[]
  color?: string
  aria?: string
}>()

const uid = useId()
const W = 100, H = 28, PAD = 2
const stroke = computed(() => props.color ?? 'var(--primary)')

/* Titik non-null saja; normalisasi min..max (netral utk seri naik/turun). */
const pts = computed<{ x: number; y: number }[] | null>(() => {
  const vals = props.values
  if (vals.filter((v) => v != null).length < 2) return null
  const nums = vals.filter((v): v is number => v != null)
  const min = Math.min(...nums)
  const max = Math.max(...nums)
  const range = max - min || 1
  return vals.flatMap((v, i) => {
    if (v == null) return []
    const x = PAD + (i * (W - PAD * 2)) / Math.max(1, vals.length - 1)
    const y = H - PAD - ((v - min) / range) * (H - PAD * 2)
    return [{ x, y }]
  })
})

const line = computed(() => (pts.value ? pts.value.map((p) => `${p.x},${p.y}`).join(' ') : ''))
/* Area di bawah garis (gradient ke transparan): sentuhan fitlink. */
const area = computed(() => {
  const p = pts.value
  if (!p || p.length < 2) return ''
  return `M${p[0].x},${H - PAD} L${p.map((q) => `${q.x},${q.y}`).join(' L')} L${p[p.length - 1].x},${H - PAD} Z`
})
</script>

<template>
  <svg
    v-if="pts"
    class="spark"
    viewBox="0 0 100 28"
    preserveAspectRatio="none"
    role="img"
    :aria-label="aria ?? 'Tren bulanan'"
  >
    <defs>
      <linearGradient :id="`spark-${uid}`" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" :stop-color="stroke" stop-opacity="0.25" />
        <stop offset="100%" :stop-color="stroke" stop-opacity="0" />
      </linearGradient>
    </defs>
    <path :d="area" :fill="`url(#spark-${uid})`" />
    <polyline
      :points="line"
      fill="none"
      :stroke="stroke"
      stroke-width="1.6"
      vector-effect="non-scaling-stroke"
      stroke-linejoin="round"
      stroke-linecap="round"
    />
  </svg>
</template>

<style scoped>
.spark {
  display: block;
  width: 100%;
  height: var(--spark-h, 30px);
}
</style>
