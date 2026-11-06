<script setup lang="ts">
import type { ComputedRef } from 'vue'
import { useRoute } from 'vue-router'
import { isPresent } from '../stores/present'

/* Pesan di atas grid widget: halaman kosong (semua disembunyikan admin)
   atau tamu melihat sebagian widget (sisanya perlu login). Di Present Mode
   ajakan login disembunyikan agar slide tetap bersih. */
defineProps<{
  w: { anyVisible: ComputedRef<boolean>; lockedCount: ComputedRef<number> }
}>()
const route = useRoute()
</script>

<template>
  <div v-if="!w.anyVisible.value && !w.lockedCount.value" class="muted wgrid-empty">
    Semua widget halaman ini disembunyikan admin.
  </div>
  <div v-else-if="w.lockedCount.value && !isPresent" class="wgrid-empty guest-note">
    <span>
      {{ w.anyVisible.value ? `${w.lockedCount.value} widget lain hanya untuk pengguna yang login.` : 'Halaman ini hanya untuk pengguna yang login.' }}
    </span>
    <RouterLink class="btn-ghost" :to="{ name: 'login', query: { redirect: route.fullPath } }">Login</RouterLink>
  </div>
</template>

<style scoped>
.guest-note {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem 1rem;
  padding: 0.6rem 0.85rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  background: var(--surface-2);
  color: var(--muted-2);
}
</style>
