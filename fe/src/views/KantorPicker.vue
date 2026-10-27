<script setup lang="ts">
/* ==========================================================================
   KantorPicker: dropdown checkbox per kantor untuk grafik & total laporan.
   Murni filter tampilan di client (data tetap dari query yang sama).
   Model = daftar kantor yang DISEMBUNYIKAN, default kosong = semua tampil.
   ========================================================================== */

const props = defineProps<{ kantors: string[] }>()
const hidden = defineModel<string[]>({ default: () => [] })

const toggle = (k: string, on: boolean): void => {
  hidden.value = on ? hidden.value.filter((x) => x !== k) : [...hidden.value, k]
}
const summary = (): string => {
  const shown = props.kantors.length - hidden.value.length
  return shown === props.kantors.length ? 'Semua kantor' : `${shown} dari ${props.kantors.length} kantor`
}
</script>

<template>
  <details v-if="kantors.length > 1" class="kantor-pick">
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
  font-size: 1rem;
}
.kantor-pick > summary {
  list-style: none;
  cursor: pointer;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 0.7rem 0.95rem;
  background: #fff;
  user-select: none;
}
.kantor-pick > summary::-webkit-details-marker {
  display: none;
}
.kantor-pick > summary::after {
  content: ' ▾';
  color: #475569;
}
.kantor-pick[open] > summary {
  border-color: var(--primary);
}
.kp-menu {
  position: absolute;
  z-index: 10;
  top: calc(100% + 0.3rem);
  left: 0;
  min-width: 16rem;
  padding: 0.6rem;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 8px 24px rgb(15 23 42 / 0.12);
}
.kp-quick-row {
  display: flex;
  justify-content: space-between;
  padding-bottom: 0.4rem;
  margin-bottom: 0.3rem;
  border-bottom: 1px solid #e2e8f0;
}
.kp-quick {
  border: 0;
  background: none;
  padding: 0;
  color: var(--primary);
  font-weight: 600;
  text-decoration: underline;
  cursor: pointer;
}
.kp-item {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  gap: 1.2rem;
  padding: 0.6rem 0.65rem;
  border-radius: 6px;
  cursor: pointer;
}
.kp-item:hover {
  background: #f1f5f9;
}
/* Checkbox custom gaya Tailwind form-checkbox (accent emerald). */
.kp-item input[type='checkbox'] {
  appearance: none;
  flex: 0 0 auto;
  width: 1.2rem;
  height: 1.2rem;
  border: 1.5px solid #94a3b8;
  border-radius: 0.25rem;
  background: #fff;
  cursor: pointer;
  position: relative;
}
.kp-item input[type='checkbox']:checked {
  background: var(--green-dark);
  border-color: var(--green-dark);
}
.kp-item input[type='checkbox']:checked::after {
  content: '';
  position: absolute;
  left: 0.34rem;
  top: 0.06rem;
  width: 0.28rem;
  height: 0.62rem;
  border: solid #fff;
  border-width: 0 2px 2px 0;
  transform: rotate(45deg);
}
.kp-item input[type='checkbox']:focus-visible {
  outline: 2px solid var(--primary);
  outline-offset: 2px;
}
</style>
