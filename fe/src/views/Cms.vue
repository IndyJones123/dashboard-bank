<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'
import { isAdmin } from '../stores/auth'
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
    out.push({ msg: `Teks utama vs kartu ${inkSurface.toFixed(1)}:1 — minimal 4.5:1`, block: true })
  const inkBg = ratio(t.ink, t.bg)
  if (inkBg != null && inkBg < 4.5)
    out.push({ msg: `Teks utama vs latar ${inkBg.toFixed(1)}:1 — minimal 4.5:1`, block: true })
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
    msg.value = 'Tema tersimpan — berlaku untuk semua user.'
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
    <h1>CMS <span class="badge in">ADMIN</span></h1>
    <p class="muted">Pengaturan tampilan global aplikasi. Khusus admin — anggota/tamu otomatis dilempar ke beranda.</p>

    <!-- Editor tema global: preview langsung (belum tersimpan), simpan ke DB -->
    <section class="panel">
      <h2>Tema Global (Palet Fitlink)</h2>
      <p class="sub">
        9 warna inti diterapkan ke seluruh aplikasi. Preview langsung (belum
        tersimpan); <strong>Simpan</strong> = berlaku untuk semua user (via /api/theme).
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
</template>

<style scoped>
/* Editor tema: UI app — nama kiri, kontrol kanan (konvensi repo). */
.theme-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px dashed var(--border);
  flex-wrap: wrap;
}
.theme-input {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
}
.tok-hex {
  width: 6.5rem;
  padding: 0.3rem 0.5rem;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--text);
  font-size: 0.85rem;
}
.tok-pick {
  width: 2.4rem;
  height: 2rem;
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
  font-size: 0.85rem;
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
