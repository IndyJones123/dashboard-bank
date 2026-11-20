<script setup lang="ts">
import { onMounted, ref } from 'vue'
import api from '../api'
import RpValue from './RpValue.vue'

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

/* Editor tema global (palet CMS fitlink) pindah ke /cms: lihat views/Cms.vue */
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
    <div class="page-head">
      <div>
        <h1>Data Rekening</h1>
        <p>20 rekening pertama, hanya untuk pengguna yang login.</p>
      </div>
    </div>
    <p v-if="error" class="alert">{{ error }}</p>

    <p v-if="loading" class="muted">Memuat data rekening…</p>
    <section v-else-if="!error" class="panel">
      <div v-if="accounts.length" class="table-scroll">
      <table>
        <thead>
          <tr><th>No. Rekening</th><th>Nasabah</th><th>Jenis</th><th class="ta-r">Saldo</th><th>Dibuka</th></tr>
        </thead>
        <tbody>
          <tr v-for="a in accounts" :key="a.id">
            <td class="num">{{ a.no_rekening }}</td>
            <td>{{ a.nasabah }}<span class="cell-sub">{{ a.kota }}</span></td>
            <td>{{ a.jenis }}</td>
            <td class="ta-r num"><RpValue :value="a.saldo" /></td>
            <td>{{ a.dibuka_pada }}</td>
          </tr>
        </tbody>
      </table>
      </div>
      <p v-else class="muted">Belum ada rekening untuk ditampilkan.</p>
    </section>
  </div>
</template>
