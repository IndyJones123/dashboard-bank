import { ref } from 'vue'
import api from '../api'

/* ==========================================================================
   Branding (CMS identitas bank): nama bank + icon (favicon) + logo.
   Sumber: GET/PUT /api/branding — gambar dikirim sebagai data URL base64
   dan disimpan DI MEMORI BE (tanpa S3/storage). Reaktif: perubahan via CMS
   langsung mengubah brand navbar, judul tab, dan favicon tanpa reload.
   ========================================================================== */

export const bankName = ref('BankDash')
export const iconUrl = ref<string | null>(null) // data URL custom; null = /favicon.svg
export const logoUrl = ref<string | null>(null) // data URL custom; null = brand SVG bawaan

const SITE_TAGLINE = 'Treasury Command'

/** Terapkan judul tab: "<nama bank> — Treasury Command". */
function applyTitle(): void {
  document.title = `${bankName.value} — ${SITE_TAGLINE}`
}

/** Ganti <link rel="icon"> ke data URL custom, atau kembali ke favicon.svg. */
function applyFavicon(): void {
  let link = document.querySelector<HTMLLinkElement>("link[rel~='icon']")
  if (!link) {
    link = document.createElement('link')
    link.rel = 'icon'
    document.head.appendChild(link)
  }
  if (iconUrl.value) {
    const semi = iconUrl.value.indexOf(';')
    link.href = iconUrl.value
    link.type = semi > 5 ? iconUrl.value.slice(5, semi) : 'image/png'
  } else {
    link.href = '/favicon.svg'
    link.type = 'image/svg+xml'
  }
}

/** Terapkan branding ke state + dokumen (judul tab & favicon). */
export function applyBranding(b: { bank_name: string; icon: string | null; logo: string | null }): void {
  bankName.value = b.bank_name || 'BankDash'
  iconUrl.value = b.icon || null
  logoUrl.value = b.logo || null
  applyTitle()
  applyFavicon()
}

/** Muat branding saat boot (sebelum mount — hindari kilatan judul default).
    Gagal (BE mati) = diam-diam pakai default BankDash. */
export async function loadBranding(): Promise<void> {
  try {
    const { data } = await api.get('/api/branding')
    applyBranding({
      bank_name: String(data?.bank_name || 'BankDash'),
      icon: typeof data?.icon === 'string' ? data.icon : null,
      logo: typeof data?.logo === 'string' ? data.logo : null,
    })
  } catch {
    applyTitle()
    applyFavicon()
  }
}

/** Simpan identitas (admin) lalu terapkan langsung ke halaman ini. */
export async function saveBranding(b: {
  bank_name: string
  icon: string | null
  logo: string | null
}): Promise<void> {
  await api.put('/api/branding', b)
  applyBranding(b)
}
