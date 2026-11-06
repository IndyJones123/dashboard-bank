<script setup lang="ts">
/* Likuiditas: halaman placeholder (menu sidebar "Segera"). Konten menyusul;
   sengaja TIDAK menampilkan angka apa pun (tidak ada data yang di-fiktif). */
import { useWidgets } from '../stores/widgets'
import WidgetNotice from './WidgetNotice.vue'

// Layout widget dari CMS (admin bisa menyembunyikan panel informasi)
const w = useWidgets('likuiditas')
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Likuiditas</h1>
      </div>
    </div>
    <WidgetNotice :w="w" />
    <div class="wgrid">
    <section v-if="w.show('info')" class="w panel" :style="w.style('info')">
      <h2>Segera tersedia</h2>
      <p class="muted">Halaman ini sedang disiapkan. Sementara itu, posisi kas dan bank ada di Laporan Keuangan Harian.</p>
      <RouterLink class="btn-ghost" :to="{ path: '/reports', query: { jenis: 'harian' } }">Buka Laporan Harian</RouterLink>
    </section>
    </div>
  </div>
</template>
