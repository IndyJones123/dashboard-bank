<script setup lang="ts">
/* Pembiayaan: halaman placeholder (menu sidebar "Segera"). Konten menyusul;
   sengaja TIDAK menampilkan angka apa pun (tidak ada data yang di-fiktif). */
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>Pembiayaan</h1>
      </div>
    </div>
    <section class="panel">
      <h2>Segera tersedia</h2>
      <p class="muted">Halaman ini sedang disiapkan. Sementara itu, posisi piutang per kantor ada di Laporan Piutang.</p>
      <RouterLink class="btn-ghost" :to="{ path: '/reports', query: { jenis: 'piutang' } }">Buka Laporan Piutang</RouterLink>
    </section>
  </div>
</template>
