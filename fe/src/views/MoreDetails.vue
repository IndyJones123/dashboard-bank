<script setup lang="ts">
/* Tombol "More details" + panel tersembunyi (v-show) utk tabel data
   terperinci di bawah grafik tiap menu laporan. Gaya: .details-btn/.details-body
   (global, dipakai bersama 4 view laporan). */
defineProps<{ id: string; open: boolean }>()
defineEmits<{ toggle: [] }>()
</script>

<template>
  <button
    type="button"
    class="details-btn"
    :class="{ open }"
    :aria-expanded="open"
    :aria-controls="id"
    @click="$emit('toggle')"
  >
    More details
    <svg class="chev" width="11" height="11" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"
      aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
  </button>
  <div :id="id" class="details-body" v-show="open">
    <slot />
  </div>
</template>
