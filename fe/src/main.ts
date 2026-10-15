import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import { refreshMe } from './stores/auth'
import './style.css'

refreshMe().finally(() => {
  createApp(App).use(router).mount('#app')
})
