<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { login } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const username = ref('admin')
const password = ref('admin123')
const loading = ref(false)
const error = ref('')

async function onSubmit(): Promise<void> {
  loading.value = true
  error.value = ''
  try {
    await login(username.value.trim(), password.value)
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/'
    await router.push(redirect)
  } catch {
    error.value = 'Username atau password salah.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-wrap">
    <form class="login-card" @submit.prevent="onSubmit">
      <h1>Login Bank</h1>
      <p class="muted">Akun mock — admin/admin123 · user/user123</p>
      <label>
        Username
        <input v-model="username" type="text" autocomplete="username" required />
      </label>
      <label>
        Password
        <input v-model="password" type="password" autocomplete="current-password" required />
      </label>
      <p v-if="error" class="alert">{{ error }}</p>
      <button class="btn" type="submit" :disabled="loading">
        {{ loading ? 'Memeriksa…' : 'Masuk' }}
      </button>
    </form>
  </div>
</template>
