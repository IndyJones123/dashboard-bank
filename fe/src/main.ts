import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { refreshMe } from './stores/auth'
import { loadTheme } from './stores/theme'
import { loadBranding } from './stores/branding'
import './style.css'

// Tema global (palet admin) + identitas bank (nama, favicon, logo) diterapkan
// SEBELUM mount — cegah kilatan judul/ikon default lalu ganti saat tersimpan.
// loadTheme/loadBranding menangkap error sendiri (BE mati -> default CSS/HTML
// berlaku), jadi mount tidak pernah tertahan olehnya.
void Promise.all([refreshMe(), loadTheme(), loadBranding()]).finally(() => {
  createApp(App).use(router).mount('#app')
})
