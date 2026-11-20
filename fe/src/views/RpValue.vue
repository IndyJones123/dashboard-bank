<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref } from 'vue'
import { formatRpM, formatRupiah, isLongNum } from '../api'

/* ==========================================================================
   RpValue: nilai Rupiah. Lebih dari 11 digit -> ringkas "Rp 1.420,6 M" +
   tombol (i) di sampingnya; klik/Enter menampilkan nilai lengkap. Nilai
   pendek tetap penuh tanpa tombol.
   - Popover di-Teleport ke <body> (position: fixed) supaya tidak terpotong
     .table-scroll / panel ber-overflow, dan tidak ikut textContent elemen
     induk (CinematicStage membaca teks .lead-value apa adanya).
   - bare: tanpa prefix "Rp" (kolom tabel Pembiayaan); popover tetap "Rp …".
   ========================================================================== */

const props = defineProps<{ value: number | string | null | undefined; bare?: boolean }>()

const long = computed(() => isLongNum(props.value))
const text = computed(() => formatRpM(props.value, props.bare))
const full = computed(() => {
  const n = Number(props.value)
  return formatRupiah(props.bare && Number.isFinite(n) ? Math.round(n) : props.value)
})

const open = ref(false)
const btn = ref<HTMLButtonElement | null>(null)
const pop = ref<HTMLElement | null>(null)
const pos = ref({ top: 0, left: 0, above: false })

function place(): void {
  const b = btn.value?.getBoundingClientRect()
  const p = pop.value
  if (!b || !p) return
  const w = p.offsetWidth
  const h = p.offsetHeight
  const vw = document.documentElement.clientWidth
  const left = Math.min(Math.max(8, b.left + b.width / 2 - w / 2), vw - w - 8)
  const above = b.bottom + 8 + h > window.innerHeight && b.top - 8 - h > 0
  pos.value = { top: above ? b.top - 8 - h : b.bottom + 8, left, above }
}

function onDocDown(e: Event): void {
  const t = e.target as Node
  if (btn.value?.contains(t) || pop.value?.contains(t)) return
  close()
}
function onKey(e: Event): void {
  if ((e as KeyboardEvent).key === 'Escape') {
    close()
    btn.value?.focus()
  }
}
function listen(on: boolean): void {
  const fn = on ? document.addEventListener : document.removeEventListener
  fn.call(document, 'pointerdown', onDocDown, true)
  fn.call(document, 'keydown', onKey)
  const wf = on ? window.addEventListener : window.removeEventListener
  wf.call(window, 'scroll', close, true)
  wf.call(window, 'resize', close)
}
function close(): void {
  if (!open.value) return
  open.value = false
  listen(false)
}
async function toggle(): Promise<void> {
  if (open.value) return close()
  open.value = true
  listen(true)
  await nextTick()
  place()
}
onUnmounted(close)
</script>

<template>
  <template v-if="!long">{{ text }}</template>
  <span v-else class="rpv" :title="full">{{ text }}<button
      ref="btn"
      type="button"
      class="rpv-btn"
      :aria-label="`Lihat nilai lengkap: ${full}`"
      :aria-expanded="open"
      @click.stop.prevent="toggle"
    ><svg viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="6.5" /><path d="M8 7.2v4M8 4.9v.1" /></svg></button></span>
  <Teleport v-if="long" to="body">
    <span
      v-if="open"
      ref="pop"
      class="rpv-pop"
      :class="{ above: pos.above }"
      role="status"
      :style="{ top: `${pos.top}px`, left: `${pos.left}px` }"
    ><small>Nilai lengkap</small>{{ full }}</span>
  </Teleport>
</template>
