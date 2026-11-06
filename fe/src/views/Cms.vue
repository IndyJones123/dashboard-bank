<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '../api'
import { isAdmin } from '../stores/auth'
import { BANK_NAME_MAX, DEFAULT_FAVICON, bankFavicon, bankLogo, bankName, saveBankName } from '../stores/branding'
import { apiErrText } from '../report-helpers'
import BrandImageField from './BrandImageField.vue'
import WidgetSettings from './WidgetSettings.vue'
import {
  DEFAULT_THEME,
  HEX6,
  LEGACY_THEME,
  THEME_TOKENS,
  applyTheme,
  contrastRatio,
  saveTheme,
  type ThemeKey,
  type ThemeTokens,
} from '../stores/theme'

const router = useRouter()
const route = useRoute()

/* Tab CMS: General (identitas + tema) | Widget Setting. Tab aktif di ?tab
   supaya bisa di-link dan bertahan saat reload. */
const CMS_TABS = [
  { id: 'general', label: 'General' },
  { id: 'widget', label: 'Widget Setting' },
] as const
type CmsTab = (typeof CMS_TABS)[number]['id']
const tab = computed<CmsTab>({
  get: () => (route.query.tab === 'widget' ? 'widget' : 'general'),
  set: (v) => void router.replace({ query: { ...route.query, tab: v === 'general' ? undefined : v } }),
})
function onTabKey(e: KeyboardEvent): void {
  if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return
  e.preventDefault()
  const i = CMS_TABS.findIndex((t) => t.id === tab.value)
  const next = CMS_TABS[(i + (e.key === 'ArrowRight' ? 1 : CMS_TABS.length - 1)) % CMS_TABS.length]
  tab.value = next.id
  document.getElementById(`cms-tab-${next.id}`)?.focus()
}

/* ---------------- Nama bank (CMS, khusus admin) ----------------
   Simpan terpisah dari tema: PUT /api/branding, berlaku untuk semua pengguna. */
const nameDraft = ref(bankName.value)
const nameSaving = ref(false)
const nameMsg = ref('')
const nameError = ref(false)
const nameClean = computed(() => nameDraft.value.trim().replace(/\s+/g, ' '))
const nameChanged = computed(() => nameClean.value !== bankName.value)

async function saveName(): Promise<void> {
  if (!nameClean.value || !nameChanged.value) return
  nameSaving.value = true
  nameMsg.value = ''
  nameError.value = false
  try {
    await saveBankName(nameClean.value)
    nameDraft.value = bankName.value
    nameMsg.value = 'Nama bank tersimpan dan berlaku untuk semua pengguna.'
  } catch (e) {
    nameError.value = true
    nameMsg.value = apiErrText(e, 'Gagal menyimpan nama bank. Pastikan login sebagai admin dan BE jalan.')
  } finally {
    nameSaving.value = false
  }
}

/* ---------------- Editor palet global (CMS, khusus admin) ----------------
   Pindahan dari Accounts: preview = applyTheme(draft) langsung ke :root
   (belum tersimpan); Simpan = PUT /api/theme (berlaku semua user);
   Batalkan = kembali ke tema tersimpan. Guard kontras: BLOK simpan bila
   teks utama < 4.5:1 di kartu/latar; peringatan lembut utk pasangan lain. */
const draft = ref<ThemeTokens>({ ...DEFAULT_THEME })
const saved = ref<ThemeTokens>({ ...DEFAULT_THEME })
const loading = ref(true)
const saving = ref(false)
const msg = ref('')

const validAll = computed(() => THEME_TOKENS.every(({ key }) => HEX6.test(draft.value[key])))

const contrastIssues = computed<{ msg: string; block: boolean }[]>(() => {
  const t = draft.value
  const out: { msg: string; block: boolean }[] = []
  const ratio = (a: string, b: string): number | null =>
    HEX6.test(a) && HEX6.test(b) ? contrastRatio(a, b) : null
  const inkSurface = ratio(t.ink, t.surface)
  if (inkSurface != null && inkSurface < 4.5)
    out.push({ msg: `Teks utama vs kartu ${inkSurface.toFixed(1)}:1, minimal 4.5:1`, block: true })
  const inkBg = ratio(t.ink, t.bg)
  if (inkBg != null && inkBg < 4.5)
    out.push({ msg: `Teks utama vs latar ${inkBg.toFixed(1)}:1, minimal 4.5:1`, block: true })
  const soft: string[] = []
  const mutedSurface = ratio(t.muted, t.surface)
  if (mutedSurface != null && mutedSurface < 4.5)
    soft.push(`muted vs kartu ${mutedSurface.toFixed(1)}:1`)
  const primarySurface = ratio(t.primary, t.surface)
  if (primarySurface != null && primarySurface < 3)
    soft.push(`primary vs kartu ${primarySurface.toFixed(1)}:1 (min 3:1)`)
  if (soft.length) out.push({ msg: `Perhatian: ${soft.join(' · ')}`, block: false })
  return out
})
const blockers = computed(() => contrastIssues.value.filter((i) => i.block))

function setToken(key: ThemeKey, v: string): void {
  draft.value = { ...draft.value, [key]: v }
  if (HEX6.test(v)) applyTheme(draft.value) // preview live per token valid
}
function usePreset(p: ThemeTokens): void {
  draft.value = { ...p }
  applyTheme(draft.value)
  msg.value = ''
}
async function save(): Promise<void> {
  saving.value = true
  msg.value = ''
  try {
    await saveTheme(draft.value)
    saved.value = { ...draft.value }
    msg.value = 'Tema tersimpan dan berlaku untuk semua pengguna.'
  } catch {
    msg.value = 'Gagal menyimpan tema (butuh login admin & BE jalan).'
  } finally {
    saving.value = false
  }
}
function revert(): void {
  draft.value = { ...saved.value }
  applyTheme(saved.value)
  msg.value = ''
}

onMounted(async () => {
  // Halamannya admin-only (route meta requiresAdmin + guard ini sbg jaring)
  if (!isAdmin.value) {
    void router.replace('/')
    return
  }
  try {
    const { data } = await api.get('/api/theme')
    const tok = data?.tokens as Partial<ThemeTokens> | undefined
    if (tok) {
      draft.value = { ...DEFAULT_THEME, ...tok }
      saved.value = { ...draft.value }
      applyTheme(draft.value)
    }
  } catch {
    /* BE mati: palet default sudah berlaku, editor tetap bisa dipakai */
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <div class="page-head">
      <div>
        <h1>CMS</h1>
        <p>Pengaturan tampilan aplikasi, khusus admin.</p>
      </div>
    </div>

    <div class="report-tabs" role="tablist" aria-label="Bagian CMS" @keydown="onTabKey">
      <button
        v-for="t in CMS_TABS"
        :id="`cms-tab-${t.id}`"
        :key="t.id"
        type="button"
        role="tab"
        :class="{ on: tab === t.id }"
        :aria-selected="tab === t.id"
        :aria-controls="`cms-panel-${t.id}`"
        :tabindex="tab === t.id ? 0 : -1"
        @click="tab = t.id"
      >{{ t.label }}</button>
    </div>

    <div v-if="tab === 'widget'" id="cms-panel-widget" role="tabpanel" aria-labelledby="cms-tab-widget">
      <WidgetSettings />
    </div>

    <div v-show="tab === 'general'" id="cms-panel-general" role="tabpanel" aria-labelledby="cms-tab-general">

    <!-- Nama bank: tampil di sidebar, halaman login, dan judul tab browser -->
    <section class="panel">
      <h2>Identitas Bank</h2>
      <p class="sub">Nama, logo, dan favicon berlaku untuk semua pengguna.</p>
      <form class="bank-form" @submit.prevent="saveName">
        <label class="label" for="bank-name">Nama bank</label>
        <input
          id="bank-name"
          v-model="nameDraft"
          class="bank-input"
          type="text"
          :maxlength="BANK_NAME_MAX"
          autocomplete="organization"
          required
        />
        <button type="submit" class="btn-navy" :disabled="nameSaving || !nameClean || !nameChanged">
          {{ nameSaving ? 'Menyimpan…' : 'Simpan nama bank' }}
        </button>
      </form>
      <p v-if="nameMsg" :class="nameError ? 'alert' : 'muted small'" role="status">{{ nameMsg }}</p>
      <BrandImageField
        kind="logo"
        label="Logo"
        hint="Tampil di sidebar dan halaman login. PNG, JPG, WebP, atau SVG, maksimal 500 KB."
        :current="bankLogo"
        :fallback="DEFAULT_FAVICON"
        accept="image/png,image/jpeg,image/webp,image/svg+xml"
        :max-bytes="500 * 1024"
      />
      <BrandImageField
        kind="favicon"
        label="Favicon"
        hint="Ikon kecil di tab browser. PNG, SVG, atau ICO, maksimal 100 KB."
        :current="bankFavicon"
        :fallback="DEFAULT_FAVICON"
        accept="image/png,image/svg+xml,image/x-icon,.ico"
        :max-bytes="100 * 1024"
      />
    </section>

    <!-- Editor tema global: preview langsung (belum tersimpan), simpan ke DB -->
    <section class="panel">
      <h2>Tema Global</h2>
      <p class="sub">
        9 warna inti, termasuk warna grafik. Perubahan tampil langsung sebagai
        pratinjau; <strong>Simpan tema</strong> menerapkannya ke semua pengguna.
      </p>
      <p v-if="loading" class="muted small">Memuat tema…</p>
      <template v-else>
        <div class="theme-row">
          <span class="label">Preset cepat</span>
          <span class="theme-actions">
            <button type="button" class="btn-outline" @click="usePreset(DEFAULT_THEME)">Fitlink (default)</button>
            <button type="button" class="btn-outline" @click="usePreset(LEGACY_THEME)">Navy legacy</button>
          </span>
        </div>
        <div v-for="t in THEME_TOKENS" :key="t.key" class="theme-row">
          <label class="label" :for="`tok-${t.key}`">{{ t.label }}</label>
          <span class="theme-input">
            <input
              :id="`tok-${t.key}`"
              class="tok-hex"
              type="text"
              :value="draft[t.key]"
              maxlength="7"
              spellcheck="false"
              :aria-label="`${t.label} (hex #RRGGBB)`"
              @input="setToken(t.key, ($event.target as HTMLInputElement).value)"
            />
            <input
              class="tok-pick"
              type="color"
              :value="HEX6.test(draft[t.key]) ? draft[t.key] : '#000000'"
              :aria-label="`${t.label} (color picker)`"
              @input="setToken(t.key, ($event.target as HTMLInputElement).value)"
            />
          </span>
        </div>
        <ul v-if="contrastIssues.length" class="theme-issues">
          <li v-for="i in contrastIssues" :key="i.msg" :class="{ block: i.block }">
            {{ i.block ? '✕' : '⚠' }} {{ i.msg }}
          </li>
        </ul>
        <div class="theme-row theme-foot">
          <span class="theme-actions">
            <button
              type="button"
              class="btn-navy"
              :disabled="saving || blockers.length > 0 || !validAll"
              @click="save"
            >
              {{ saving ? 'Menyimpan…' : 'Simpan tema' }}
            </button>
            <button type="button" class="btn-ghost" @click="revert">Batalkan perubahan</button>
          </span>
          <span v-if="msg" class="muted small">{{ msg }}</span>
        </div>
      </template>
    </section>
    </div>
  </div>
</template>

<style scoped>
/* Form nama bank: nama kiri, kontrol kanan; turun baris di layar sempit. */
.bank-form {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 0.75rem;
}
.bank-form .label {
  font-weight: 600;
}
.bank-input {
  flex: 1 1 18rem;
  min-width: 0;
  max-width: 32rem;
  min-height: 44px;
  padding: 0.4rem 0.7rem;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--ink);
  font-family: var(--font-body);
  font-size: var(--fs-base);
}
.bank-form + p {
  margin: 0.6rem 0 0;
}

/* Editor tema: UI app: nama kiri, kontrol kanan (konvensi repo). */
.theme-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px solid var(--border);
  flex-wrap: wrap;
}
.theme-row .label {
  font-weight: 600;
}
.theme-input {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
}
.tok-hex {
  width: 7rem;
  min-height: 44px;
  padding: 0.3rem 0.5rem;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--text);
  font-family: var(--font-body);
  font-size: var(--fs-base);
  font-variant-numeric: tabular-nums;
}
.tok-pick {
  width: 2.75rem;
  height: 44px;
  padding: 0;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: none;
  cursor: pointer;
}
.theme-actions {
  display: inline-flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}
.theme-issues {
  margin: 0.6rem 0 0;
  padding: 0;
  list-style: none;
  font-size: var(--fs-sm);
}
.theme-issues li {
  padding: 0.2rem 0;
  color: var(--amber);
}
.theme-issues li.block {
  color: var(--red);
  font-weight: 600;
}
.theme-foot {
  border-bottom: 0;
  padding-top: 0.8rem;
}
</style>
