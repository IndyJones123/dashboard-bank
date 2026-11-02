import { ref } from 'vue'
import api from '../api'

/* ==========================================================================
   Identitas bank global (CMS): nama, logo, favicon. GET /api/branding,
   disimpan di app_settings. Logo/favicon = data URL, kosong = gambar bawaan.
   Dipakai sidebar, bar atas mobile, halaman login, dan tab browser.
   BE mati -> nilai default, aplikasi tetap terbuka.
   ========================================================================== */

export const DEFAULT_BANK_NAME = 'BankDash'
export const BANK_NAME_MAX = 60
export const DEFAULT_FAVICON = '/favicon.svg'

export type BrandImageKind = 'logo' | 'favicon'

export const bankName = ref(DEFAULT_BANK_NAME)
export const bankLogo = ref('')
export const bankFavicon = ref('')

function applyBankName(name: string): void {
  bankName.value = name
  document.title = `${name}: Treasury Command`
}

function applyLogo(url: string): void {
  bankLogo.value = url
}

function applyFavicon(url: string): void {
  bankFavicon.value = url
  const link = document.querySelector<HTMLLinkElement>('link[rel="icon"]')
  if (!link) return
  link.href = url || DEFAULT_FAVICON
  // Tipe bawaan index.html (svg) tidak berlaku lagi untuk file unggahan
  if (url) link.removeAttribute('type')
  else link.type = 'image/svg+xml'
}

/** Muat identitas bank saat boot (publik; gagal -> default). */
export async function loadBranding(): Promise<void> {
  try {
    const { data } = await api.get('/api/branding')
    if (data?.bank_name) applyBankName(String(data.bank_name))
    applyLogo(data?.logo ? String(data.logo) : '')
    applyFavicon(data?.favicon ? String(data.favicon) : '')
  } catch {
    /* BE mati / jaringan: nilai default tetap berlaku */
  }
}

/** Simpan nama bank (admin); terapkan hasil server, bukan input lokal. */
export async function saveBankName(name: string): Promise<void> {
  const { data } = await api.put('/api/branding', { bank_name: name })
  if (data?.bank_name) applyBankName(String(data.bank_name))
}

/** Simpan logo/favicon (admin); dataUrl kosong = hapus, kembali ke bawaan.
    Terapkan hasil server: server menyusun ulang data URL dari isi file. */
export async function saveBrandImage(kind: BrandImageKind, dataUrl: string): Promise<void> {
  const { data } = await api.put('/api/branding/image', { kind, data_url: dataUrl })
  const url = data?.data_url ? String(data.data_url) : ''
  if (kind === 'logo') applyLogo(url)
  else applyFavicon(url)
}
