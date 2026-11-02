<script setup lang="ts">
import { ref } from 'vue'

/* ==========================================================================
   KantorPicker: dropdown checkbox per kantor untuk grafik & total laporan.
   Murni filter tampilan di client (data tetap dari query yang sama).
   Model = daftar kantor yang DISEMBUNYIKAN, default kosong = semua tampil.
   ========================================================================== */

const props = defineProps<{ kantors: string[] }>()
const hidden = defineModel<string[]>({ default: () => [] })

const root = ref<HTMLDetailsElement | null>(null)

const toggle = (k: string, on: boolean): void => {
  hidden.value = on ? hidden.value.filter((x) => x !== k) : [...hidden.value, k]
}
const summary = (): string => {
  const shown = props.kantors.length - hidden.value.length
  return shown === props.kantors.length ? 'Semua kantor' : `${shown} dari ${props.kantors.length} kantor`
}
/** Esc menutup menu & mengembalikan fokus ke pemicunya. */
const closeMenu = (): void => {
  const el = root.value
  if (!el?.open) return
  el.open = false
  el.querySelector('summary')?.focus()
}
</script>

<template>
  <details v-if="kantors.length > 1" ref="root" class="kantor-pick" @keydown.esc="closeMenu">
    <summary>
      Kantor: <strong>{{ summary() }}</strong>
    </summary>
    <div class="kp-menu">
      <div class="kp-quick-row">
        <button type="button" class="kp-quick" @click="hidden = []">Pilih semua</button>
        <button type="button" class="kp-quick" @click="hidden = [...kantors]">Kosongkan</button>
      </div>
      <label v-for="k in kantors" :key="k" class="kp-item">
        Kantor {{ k }}
        <input
          type="checkbox"
          :checked="!hidden.includes(k)"
          @change="toggle(k, ($event.target as HTMLInputElement).checked)"
        />
      </label>
    </div>
  </details>
</template>

<style scoped>
.kantor-pick {
  position: relative;
  display: inline-block;
  font-size: var(--fs-base);
}
.kantor-pick > summary {
  list-style: none;
  display: flex;
  align-items: center;
  gap: 0.3rem;
  min-height: 44px;
  padding: 0.4rem 0.75rem;
  cursor: pointer;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--muted-2);
  font-weight: 600;
  user-select: none;
}
.kantor-pick > summary strong {
  color: var(--ink);
  font-weight: 500;
}
.kantor-pick > summary:hover {
  border-color: var(--primary);
}
.kantor-pick > summary::-webkit-details-marker {
  display: none;
}
.kantor-pick > summary::after {
  content: '▾';
  color: var(--muted);
}
.kantor-pick[open] > summary {
  border-color: var(--primary);
}
/* Shadow: menu melayang di atas grafik, satu-satunya elemen terangkat di sini */
.kp-menu {
  position: absolute;
  z-index: 10;
  top: calc(100% + 0.3rem);
  left: 0;
  min-width: 16rem;
  padding: 0.5rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  background: var(--surface);
  box-shadow: var(--shadow-raised);
}
.kp-quick-row {
  display: flex;
  justify-content: space-between;
  padding-bottom: 0.25rem;
  margin-bottom: 0.25rem;
  border-bottom: 1px solid var(--border-strong);
}
.kp-quick {
  min-height: 44px;
  padding: 0 0.5rem;
  border: 0;
  background: none;
  color: var(--primary);
  font-family: inherit;
  font-size: var(--fs-base);
  font-weight: 600;
  cursor: pointer;
}
.kp-quick:hover {
  text-decoration: underline;
}
.kp-item {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  gap: 1.2rem;
  min-height: 44px;
  padding: 0.3rem 0.5rem;
  border-radius: 6px;
  color: var(--ink);
  font-weight: 500;
  cursor: pointer;
}
.kp-item:hover {
  background: var(--surface-2);
}
.kp-item input[type='checkbox'] {
  appearance: none;
  flex: 0 0 auto;
  width: 1.25rem;
  height: 1.25rem;
  margin: 0;
  border: 1.5px solid var(--muted);
  border-radius: 0.25rem;
  background: var(--surface);
  cursor: pointer;
  position: relative;
}
.kp-item input[type='checkbox']:checked {
  background: var(--primary);
  border-color: var(--primary);
}
.kp-item input[type='checkbox']:checked::after {
  content: '';
  position: absolute;
  left: 0.36rem;
  top: 0.08rem;
  width: 0.28rem;
  height: 0.62rem;
  border: solid #fff;
  border-width: 0 2px 2px 0;
  transform: rotate(45deg);
}
</style>
