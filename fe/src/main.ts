import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { refreshMe } from './stores/auth'
import { loadBranding } from './stores/branding'
import { loadTheme } from './stores/theme'
import './style.css'

// Tema global & nama bank diterapkan SEBELUM mount: cegah kilatan warna/nama
// default lalu ganti saat nilai tersimpan berbeda. Keduanya menangkap error
// sendiri (BE mati -> default berlaku), jadi mount tidak pernah tertahan.
void Promise.all([refreshMe(), loadTheme(), loadBranding()]).finally(() => {
  createApp(App).use(router).mount('#app')
})
