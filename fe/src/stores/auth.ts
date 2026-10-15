import { computed, reactive } from 'vue'
import api from '../api'

export interface User {
  id: number | string
  username: string
  full_name: string
  role: string
}

const state = reactive<{ token: string; user: User | null }>({
  token: localStorage.getItem('bank_token') ?? '',
  user: JSON.parse(localStorage.getItem('bank_user') ?? 'null'),
})

export const isLoggedIn = computed(() => !!state.token && !!state.user)
export const currentUser = computed(() => state.user)
export const isAdmin = computed(() => state.user?.role === 'admin')

export async function login(username: string, password: string): Promise<User> {
  const { data } = await api.post('/api/login', { username, password })
  state.token = data.token
  state.user = data.user
  localStorage.setItem('bank_token', data.token)
  localStorage.setItem('bank_user', JSON.stringify(data.user))
  return data.user
}

export function logout(): void {
  state.token = ''
  state.user = null
  localStorage.removeItem('bank_token')
  localStorage.removeItem('bank_user')
}

export async function refreshMe(): Promise<void> {
  if (!state.token) return
  try {
    const { data } = await api.get('/api/me')
    state.user = {
      id: data.id,
      username: data.username,
      full_name: data.full_name ?? '',
      role: data.role ?? 'member',
    }
    localStorage.setItem('bank_user', JSON.stringify(state.user))
  } catch {
    logout()
  }
}
