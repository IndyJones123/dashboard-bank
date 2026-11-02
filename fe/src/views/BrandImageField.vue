<script setup lang="ts">
import { computed, ref } from 'vue'
import { apiErrText } from '../report-helpers'
import { saveBrandImage, type BrandImageKind } from '../stores/branding'

/* ==========================================================================
   BrandImageField: baris CMS untuk unggah logo/favicon. Pratinjau dulu,
   tersimpan setelah tombol Simpan (pola sama dgn editor tema). Cek tipe &
   ukuran di sini hanya untuk pesan cepat; validasi sebenarnya di server.
   ========================================================================== */

const props = defineProps<{
  kind: BrandImageKind
  label: string
  hint: string
  current: string
  fallback: string
  accept: string
  maxBytes: number
}>()

const input = ref<HTMLInputElement | null>(null)
const draft = ref('')
const saving = ref(false)
const msg = ref('')
const isError = ref(false)

const preview = computed(() => draft.value || props.current || props.fallback)
const isDefault = computed(() => !draft.value && !props.current)

function show(text: string, error = false): void {
  msg.value = text
  isError.value = error
}

function onPick(e: Event): void {
  const el = e.target as HTMLInputElement
  const file = el.files?.[0]
  el.value = '' // file yang sama bisa dipilih lagi setelah dibatalkan
  if (!file) return
  if (file.size > props.maxBytes) {
    show(`Ukuran file maksimal ${Math.round(props.maxBytes / 1024)} KB. File ini ${Math.ceil(file.size / 1024)} KB.`, true)
    return
  }
  const reader = new FileReader()
  reader.onload = () => {
    draft.value = String(reader.result ?? '')
    show('Pratinjau, belum tersimpan.')
  }
  reader.onerror = () => show('File tidak bisa dibaca. Coba pilih file lain.', true)
  reader.readAsDataURL(file)
}

async function store(value: string, done: string): Promise<void> {
  saving.value = true
  show('')
  try {
    await saveBrandImage(props.kind, value)
    draft.value = ''
    show(done)
  } catch (e) {
    show(apiErrText(e, 'Gagal menyimpan gambar. Pastikan login sebagai admin dan BE jalan.'), true)
  } finally {
    saving.value = false
  }
}

function cancel(): void {
  draft.value = ''
  show('')
}
</script>

<template>
  <div class="bi-row">
    <div class="bi-preview" :class="`bi-${kind}`">
      <img :src="preview" :alt="`Pratinjau ${label.toLowerCase()}`" />
    </div>
    <div class="bi-body">
      <strong>{{ label }}</strong>
      <span class="muted small">{{ hint }}</span>
      <p v-if="msg" :class="isError ? 'alert' : 'muted small'" role="status">{{ msg }}</p>
    </div>
    <div class="bi-actions">
      <input ref="input" class="bi-file" type="file" :accept="accept" aria-hidden="true" tabindex="-1" @change="onPick" />
      <template v-if="draft">
        <button type="button" class="btn-navy" :disabled="saving" @click="store(draft, `${label} tersimpan dan berlaku untuk semua pengguna.`)">
          {{ saving ? 'Menyimpan…' : `Simpan ${label.toLowerCase()}` }}
        </button>
        <button type="button" class="btn-ghost" :disabled="saving" @click="cancel">Batalkan</button>
      </template>
      <template v-else>
        <button type="button" class="btn-ghost" @click="input?.click()">Pilih file {{ label.toLowerCase() }}</button>
        <button
          v-if="!isDefault"
          type="button"
          class="btn-ghost"
          :disabled="saving"
          @click="store('', `${label} dikembalikan ke bawaan.`)"
        >Hapus {{ label.toLowerCase() }}</button>
      </template>
    </div>
  </div>
</template>

<style scoped>
.bi-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem 1rem;
  padding: 0.75rem 0 0;
  margin-top: 0.75rem;
  border-top: 1px solid var(--border);
}
.bi-preview {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  background: var(--surface);
  overflow: hidden;
}
.bi-logo {
  width: 64px;
  height: 64px;
  padding: 6px;
}
.bi-favicon {
  width: 64px;
  height: 64px;
  padding: 16px;
}
.bi-preview img {
  display: block;
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.bi-body {
  flex: 1 1 16rem;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}
.bi-body p {
  margin: 0.25rem 0 0;
}
.bi-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}
/* Input asli disembunyikan; tombol di sebelahnya yang bisa difokus keyboard */
.bi-file {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
  pointer-events: none;
}
</style>
