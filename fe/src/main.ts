import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { refreshMe } from './stores/auth'
import { loadTheme } from './stores/theme'
import './style.css'

// Tema global (palet admin) diterapkan SEBELUM mount — cegah kilatan warna
// default lalu ganti saat tema tersimpan berbeda. loadTheme menangkap error
// sendiri (BE mati -> palet default CSS berlaku), jadi mount tidak pernah
// tertahan olehnya.
void Promise.all([refreshMe(), loadTheme()]).finally(() => {
  createApp(App).use(router).mount('#app')
})
