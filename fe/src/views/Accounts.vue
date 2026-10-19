<script setup lang="ts">
import { onMounted, ref } from 'vue'
import api, { formatRupiah } from '../api'

interface Account {
  id: number
  no_rekening: string
  jenis: string
  saldo: number
  dibuka_pada: string
  nasabah: string
  kota: string
}

const accounts = ref<Account[]>([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    const { data } = await api.get('/api/accounts', { params: { limit: 20 } })
    accounts.value = data
  } catch {
    error.value = 'Gagal memuat data rekening (butuh login).'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <h1>Data Rekening <span class="badge in">LOGIN</span></h1>
    <p class="muted">Halaman ini dilindungi route-guard, tamu otomatis dilempar ke halaman login.</p>
    <p v-if="error" class="alert">{{ error }}</p>
    <p v-if="loading" class="muted">Memuat…</p>
    <section v-else class="panel">
      <div class="table-scroll">
      <table>
        <thead>
          <tr><th>No. Rekening</th><th>Nasabah</th><th>Jenis</th><th>Saldo</th><th>Dibuka</th></tr>
        </thead>
        <tbody>
          <tr v-for="a in accounts" :key="a.id">
            <td>{{ a.no_rekening }}</td>
            <td>{{ a.nasabah }}<br /><small class="muted">{{ a.kota }}</small></td>
            <td>{{ a.jenis }}</td>
            <td>{{ formatRupiah(a.saldo) }}</td>
            <td>{{ a.dibuka_pada }}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </section>
  </div>
</template>
