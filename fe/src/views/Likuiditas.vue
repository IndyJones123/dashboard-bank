<script setup lang="ts">
/* Likuiditas: halaman placeholder (menu sidebar "Segera"). Konten menyusul;
   sengaja TIDAK menampilkan angka apa pun (tidak ada data yang di-fiktif). */
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Likuiditas</h1>
      </div>
    </div>
    <section class="panel">
      <h2>Segera tersedia</h2>
      <p class="muted">Halaman ini sedang disiapkan. Sementara itu, posisi kas dan bank ada di Laporan Keuangan Harian.</p>
      <RouterLink class="btn-ghost" :to="{ path: '/reports', query: { jenis: 'harian' } }">Buka Laporan Harian</RouterLink>
    </section>
  </div>
</template>
