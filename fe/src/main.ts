import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { refreshMe } from './stores/auth'
import { loadBranding } from './stores/branding'
import { loadTheme } from './stores/theme'
import { loadWidgets } from './stores/widgets'
import './style.css'

// Tema global, nama bank, dan layout widget diterapkan SEBELUM mount: cegah
// kilatan tampilan default lalu ganti saat nilai tersimpan berbeda. Semuanya
// menangkap error sendiri (BE mati -> default berlaku), mount tak tertahan.
void Promise.all([refreshMe(), loadTheme(), loadBranding(), loadWidgets()]).finally(() => {
  createApp(App).use(router).mount('#app')
})
