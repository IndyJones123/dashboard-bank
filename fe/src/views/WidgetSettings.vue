<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { apiErrText } from '../report-helpers'
import {
  PREVIEW_MSG,
  PREVIEW_PARAM,
  WIDGET_PAGES,
  WIDGET_SPANS,
  defaultItems,
  mergeItems,
  packRows,
  pageDef,
  saveWidgets,
  savedPages,
  type WidgetItem,
  type WidgetKind,
  type WidgetPages,
} from '../stores/widgets'

/* Editor layout widget (CMS > Widget Setting). Semua perubahan masuk draft;
   halaman asli baru berubah setelah "Simpan layout" (PUT /api/widgets).
   Urutan: drag & drop blok di kanvas, atau tombol panah (keyboard/layar sentuh). */

const KIND_LABEL: Record<WidgetKind, string> = {
  angka: 'Angka utama',
  ringkasan: 'Ringkasan',
  grafik: 'Grafik',
  tabel: 'Tabel',
  info: 'Informasi',
}

function fromSaved(): WidgetPages {
  return Object.fromEntries(WIDGET_PAGES.map((p) => [p.id, mergeItems(p.id, savedPages.value[p.id])]))
}

const draft = ref<WidgetPages>(fromSaved())
const baseline = ref(JSON.stringify(draft.value))
const pageId = ref(WIDGET_PAGES[0].id)
const saving = ref(false)
const msg = ref('')
const msgError = ref(false)
const live = ref('') // pengumuman pembaca layar saat urutan berubah

const page = computed(() => pageDef(pageId.value)!)
const items = computed(() => draft.value[pageId.value] ?? [])
const spans = computed(() => packRows(items.value))
const visibleItems = computed(() => items.value.filter((it) => it.visible))
const hiddenItems = computed(() => items.value.filter((it) => !it.visible))
const dirty = computed(() => JSON.stringify(draft.value) !== baseline.value)
const baseByPage = computed(() => JSON.parse(baseline.value) as WidgetPages)
const pageDirty = (id: string): boolean =>
  JSON.stringify(draft.value[id]) !== JSON.stringify(baseByPage.value[id])
const isDefault = computed(
  () => JSON.stringify(items.value) === JSON.stringify(defaultItems(pageId.value)),
)

const defOf = (id: string) => page.value.widgets.find((w) => w.id === id)!
const labelOf = (id: string): string => defOf(id)?.label ?? id

function setItems(next: WidgetItem[]): void {
  draft.value = { ...draft.value, [pageId.value]: next }
  msg.value = ''
}

function patch(id: string, p: Partial<WidgetItem>): void {
  setItems(items.value.map((it) => (it.id === id ? { ...it, ...p } : it)))
}

/** Pindahkan widget `id` ke posisi widget `targetId` di daftar penuh. */
function moveTo(id: string, targetId: string): void {
  if (id === targetId) return
  const list = [...items.value]
  const from = list.findIndex((it) => it.id === id)
  const to = list.findIndex((it) => it.id === targetId)
  if (from < 0 || to < 0) return
  const [it] = list.splice(from, 1)
  list.splice(to, 0, it)
  setItems(list)
}

/** Geser satu langkah di antara widget yang tampil (tombol panah). */
function step(id: string, dir: -1 | 1): void {
  const vis = visibleItems.value
  const i = vis.findIndex((it) => it.id === id)
  const target = vis[i + dir]
  if (!target) return
  moveTo(id, target.id)
  live.value = `${labelOf(id)} dipindah ke posisi ${i + dir + 1} dari ${vis.length}`
}

/* ---- Drag & drop (HTML5): urutan berubah langsung saat melewati blok lain ---- */
const dragId = ref<string | null>(null)
function onDragStart(e: DragEvent, id: string): void {
  dragId.value = id
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', id)
  }
}
function onDragEnter(id: string): void {
  if (dragId.value && dragId.value !== id) moveTo(dragId.value, id)
}
function onDragEnd(): void {
  if (dragId.value) live.value = `${labelOf(dragId.value)} dipindahkan`
  dragId.value = null
}

function resetPage(): void {
  setItems(defaultItems(pageId.value))
  live.value = `Layout ${page.value.label} kembali ke default. Simpan untuk menerapkan.`
}

function revert(): void {
  draft.value = JSON.parse(baseline.value) as WidgetPages
  msg.value = ''
}

/* ---- Pratinjau langsung: halaman asli di iframe (?wpreview=1) ----
   Draft dikirim lewat postMessage tiap berubah; iframe dirender selebar
   viewport aslinya lalu diperkecil (transform) agar muat di panel. */
const VIEWPORTS = [
  { id: 'desktop', label: 'Desktop', w: 1440, h: 1000 },
  { id: 'hp', label: 'HP', w: 390, h: 844 },
] as const
type Viewport = (typeof VIEWPORTS)[number]
const vp = ref<Viewport>(VIEWPORTS[0])
const asGuest = ref(false) // pratinjau dari sudut pandang tamu (tanpa login)
const frame = ref<HTMLIFrameElement | null>(null)
const stage = ref<HTMLElement | null>(null)
const stageW = ref(0)
const scale = computed(() => (stageW.value ? Math.min(1, stageW.value / vp.value.w) : 1))
const previewSrc = computed(() => {
  const to = page.value.to
  return `${to}${to.includes('?') ? '&' : '?'}${PREVIEW_PARAM}=1`
})

function pushPreview(): void {
  frame.value?.contentWindow?.postMessage(
    { type: PREVIEW_MSG, pages: JSON.parse(JSON.stringify(draft.value)), asGuest: asGuest.value },
    window.location.origin,
  )
}
watch([draft, asGuest], pushPreview, { deep: true })

function onFrameMessage(e: MessageEvent): void {
  if (e.origin !== window.location.origin || e.source !== frame.value?.contentWindow) return
  if ((e.data as { type?: string } | null)?.type === `${PREVIEW_MSG}-ready`) pushPreview()
}
let ro: ResizeObserver | null = null
onMounted(() => {
  window.addEventListener('message', onFrameMessage)
  if (stage.value) {
    ro = new ResizeObserver(([entry]) => {
      stageW.value = entry.contentRect.width
    })
    ro.observe(stage.value)
  }
})
onUnmounted(() => {
  window.removeEventListener('message', onFrameMessage)
  ro?.disconnect()
})

async function save(): Promise<void> {
  saving.value = true
  msg.value = ''
  msgError.value = false
  try {
    await saveWidgets(draft.value)
    draft.value = fromSaved()
    baseline.value = JSON.stringify(draft.value)
    msg.value = 'Layout tersimpan. Semua pengguna dan Present Mode memakai layout ini.'
  } catch (e) {
    msgError.value = true
    msg.value = apiErrText(e, 'Gagal menyimpan layout. Pastikan login sebagai admin dan BE jalan.')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <section class="panel">
    <div class="toolbar ws-head">
      <div>
        <h2>Widget Setting</h2>
        <p class="sub">
          Atur widget tiap halaman: geser untuk mengubah urutan, ubah lebar, atau
          sembunyikan. Widget di sebelahnya otomatis melebar mengisi ruang kosong.
        </p>
      </div>
      <div class="filters">
        <label>
          Halaman
          <select v-model="pageId">
            <option v-for="p in WIDGET_PAGES" :key="p.id" :value="p.id">
              {{ p.label }}{{ pageDirty(p.id) ? ' (belum disimpan)' : '' }}
            </option>
          </select>
        </label>
      </div>
    </div>

    <!-- Kanvas pratinjau: 12 kolom, lebar blok = lebar efektif di halaman -->
    <p class="label ws-label">Tampil di halaman ({{ visibleItems.length }})</p>
    <ol v-if="visibleItems.length" class="ws-canvas" aria-label="Urutan widget yang tampil">
      <li
        v-for="(it, i) in visibleItems"
        :key="it.id"
        class="ws-block"
        :class="[`k-${defOf(it.id).kind}`, { dragging: dragId === it.id }]"
        :style="{ '--span': spans.get(it.id) ?? it.span }"
        draggable="true"
        @dragstart="onDragStart($event, it.id)"
        @dragenter.prevent="onDragEnter(it.id)"
        @dragover.prevent
        @drop.prevent
        @dragend="onDragEnd"
      >
        <div class="ws-top">
          <span class="ws-grip" aria-hidden="true" title="Seret untuk memindahkan">
            <svg class="ico-svg" viewBox="0 0 24 24"><path d="M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01" /></svg>
          </span>
          <span class="ws-name">
            <strong>{{ defOf(it.id).label }}</strong>
            <small>{{ KIND_LABEL[defOf(it.id).kind] }} · {{ i + 1 }}</small>
          </span>
        </div>

        <!-- Akses tamu: tampil tanpa login atau perlu login -->
        <button
          type="button"
          class="ws-guest"
          :class="{ on: it.guest }"
          :aria-pressed="it.guest"
          :aria-label="`${defOf(it.id).label}: ${it.guest ? 'tampil untuk tamu' : 'perlu login'}. Klik untuk mengubah`"
          @click="patch(it.id, { guest: !it.guest })"
        >
          <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
            <rect x="5" y="11" width="14" height="9" rx="2" />
            <path v-if="it.guest" d="M8 11V8a4 4 0 0 1 7.5-2" />
            <path v-else d="M8 11V8a4 4 0 0 1 8 0v3" />
          </svg>
          {{ it.guest ? 'Tamu boleh lihat' : 'Perlu login' }}
        </button>

        <!-- Sketsa isi widget (bukan data asli) supaya blok mudah dikenali -->
        <div class="ws-sketch" aria-hidden="true">
          <template v-if="defOf(it.id).kind === 'grafik'">
            <i v-for="n in 7" :key="n" :style="{ height: `${30 + ((n * 37) % 60)}%` }" />
          </template>
          <template v-else>
            <i v-for="n in defOf(it.id).kind === 'angka' ? 1 : 3" :key="n" />
          </template>
        </div>

        <div class="ws-ctrl">
          <label class="ws-size">
            <span class="sr-only">Lebar {{ defOf(it.id).label }}</span>
            <select :value="it.span" @change="patch(it.id, { span: Number(($event.target as HTMLSelectElement).value) })">
              <option v-for="s in WIDGET_SPANS" :key="s.span" :value="s.span">{{ s.label }}</option>
            </select>
          </label>
          <button
            type="button" class="ws-icon" :disabled="i === 0"
            :aria-label="`Pindah ${defOf(it.id).label} ke kiri atau atas`"
            @click="step(it.id, -1)"
          >
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 6l-6 6 6 6" /></svg>
          </button>
          <button
            type="button" class="ws-icon" :disabled="i === visibleItems.length - 1"
            :aria-label="`Pindah ${defOf(it.id).label} ke kanan atau bawah`"
            @click="step(it.id, 1)"
          >
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
          </button>
          <button
            type="button" class="ws-icon"
            :aria-label="`Sembunyikan ${defOf(it.id).label}`"
            title="Sembunyikan"
            @click="patch(it.id, { visible: false })"
          >
            <svg class="ico-svg" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M3 3l18 18M10.6 10.6a2 2 0 0 0 2.8 2.8M9.9 5.2A9.7 9.7 0 0 1 12 5c5 0 8.5 4.5 9.5 7-.4 1-1.2 2.3-2.4 3.5M6.2 6.2C4.3 7.5 3 9.4 2.5 12c1 2.5 4.5 7 9.5 7 1.8 0 3.4-.6 4.8-1.4" />
            </svg>
          </button>
        </div>
      </li>
    </ol>
    <p v-else class="muted ws-empty">Semua widget disembunyikan. Halaman ini akan kosong.</p>

    <p class="label ws-label">Disembunyikan ({{ hiddenItems.length }})</p>
    <ul v-if="hiddenItems.length" class="ws-hidden">
      <li v-for="it in hiddenItems" :key="it.id">
        <span>
          <strong>{{ defOf(it.id).label }}</strong>
          <small>{{ KIND_LABEL[defOf(it.id).kind] }} · {{ it.guest ? 'Tamu boleh lihat' : 'Perlu login' }}</small>
        </span>
        <button type="button" class="btn-outline" @click="patch(it.id, { visible: true })">Tampilkan</button>
      </li>
    </ul>
    <p v-else class="muted small ws-empty">Tidak ada widget tersembunyi.</p>

    <!-- Pratinjau halaman asli dengan layout draft (belum disimpan) -->
    <div class="ws-preview">
      <div class="ws-preview-head">
        <div>
          <h3>Pratinjau {{ page.label }}</h3>
          <p class="muted small">
            Halaman asli dengan data asli. Berubah langsung saat layout diatur, sebelum disimpan.
            Pilih <strong>Tamu</strong> untuk melihat tampilan tanpa login.
          </p>
        </div>
        <div class="ws-preview-tools">
        <div class="segmented" role="group" aria-label="Lihat pratinjau sebagai">
          <button type="button" :class="{ on: !asGuest }" :aria-pressed="!asGuest" @click="asGuest = false">Login</button>
          <button type="button" :class="{ on: asGuest }" :aria-pressed="asGuest" @click="asGuest = true">Tamu</button>
        </div>
        <div class="segmented" role="group" aria-label="Ukuran layar pratinjau">
          <button
            v-for="v in VIEWPORTS"
            :key="v.id"
            type="button"
            :class="{ on: vp.id === v.id }"
            :aria-pressed="vp.id === v.id"
            @click="vp = v"
          >{{ v.label }}</button>
        </div>
        </div>
      </div>
      <div ref="stage" class="ws-stage" :style="{ height: `${vp.h * scale}px` }">
        <iframe
          ref="frame"
          :key="previewSrc"
          :src="previewSrc"
          :title="`Pratinjau halaman ${page.label}`"
          :width="vp.w"
          :height="vp.h"
          :style="{ transform: `scale(${scale})`, width: `${vp.w}px`, height: `${vp.h}px` }"
          @load="pushPreview"
        />
      </div>
    </div>

    <div class="ws-foot">
      <span class="ws-actions">
        <button type="button" class="btn-navy" :disabled="saving || !dirty" @click="save">
          {{ saving ? 'Menyimpan…' : 'Simpan layout' }}
        </button>
        <button type="button" class="btn-ghost" :disabled="!dirty" @click="revert">Batalkan perubahan</button>
        <button type="button" class="btn-ghost" :disabled="isDefault" @click="resetPage">
          Reset {{ page.label }} ke default
        </button>
      </span>
      <RouterLink class="ws-open" :to="page.to">Lihat halaman {{ page.label }}</RouterLink>
    </div>
    <p v-if="msg" :class="msgError ? 'alert' : 'muted small'" role="status">{{ msg }}</p>
    <p v-else-if="dirty" class="muted small">Ada perubahan yang belum disimpan.</p>
    <p class="sr-only" aria-live="polite">{{ live }}</p>
  </section>
</template>

<style scoped>
.ws-head { align-items: flex-start; margin-bottom: 0.5rem; }
.ws-label { margin: 0.75rem 0 0.4rem; font-weight: 600; color: var(--muted-2); }
.ws-empty { margin: 0 0 0.5rem; }

.ws-canvas {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 0.6rem;
  margin: 0;
  padding: 0.75rem;
  list-style: none;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
}
.ws-block {
  grid-column: span var(--span, 12);
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  min-width: 0;
  padding: 0.6rem 0.7rem;
  background: var(--surface);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  cursor: grab;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.ws-block:hover { border-color: var(--primary-40); }
.ws-block.dragging {
  opacity: 0.55;
  border-style: dashed;
  border-color: var(--primary);
}
.ws-block:active { cursor: grabbing; }

.ws-top { display: flex; align-items: flex-start; gap: 0.4rem; min-width: 0; }
.ws-grip { color: var(--muted); padding-top: 0.1rem; }
.ws-grip .ico-svg { stroke-width: 3; }
.ws-name { display: flex; flex-direction: column; min-width: 0; }
.ws-name strong { font-size: var(--fs-sm); line-height: 1.3; overflow-wrap: anywhere; }
.ws-name small { color: var(--muted); font-size: 0.75rem; }

/* Sketsa: batang abu-abu, bentuk mengikuti jenis widget */
.ws-sketch {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  height: 3rem;
  justify-content: center;
}
.ws-sketch i { display: block; height: 0.45rem; border-radius: 3px; background: var(--ink-10); }
.k-angka .ws-sketch i { height: 1.1rem; width: 70%; background: var(--primary-10); }
.k-ringkasan .ws-sketch i:nth-child(2) { width: 85%; }
.k-ringkasan .ws-sketch i:nth-child(3) { width: 65%; }
.k-grafik .ws-sketch { flex-direction: row; align-items: flex-end; gap: 0.25rem; }
.k-grafik .ws-sketch i { flex: 1; width: auto; background: var(--primary-10); }

.ws-ctrl { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem; margin-top: auto; }
.ws-size { flex: 1 1 5.5rem; min-width: 0; }
.ws-size select {
  width: 100%;
  min-height: 36px;
  padding: 0.2rem 0.4rem;
  border: 1px solid var(--ink-16);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--ink);
  font-family: var(--font-body);
  font-size: var(--fs-sm);
}
.ws-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  padding: 0;
  background: var(--surface);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  color: var(--ink);
  cursor: pointer;
}
.ws-icon:hover:not(:disabled) { border-color: var(--primary); color: var(--primary); }
.ws-icon:disabled { opacity: 0.35; cursor: default; }

.ws-hidden { list-style: none; margin: 0; padding: 0; }
.ws-hidden li {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px solid var(--border);
}
.ws-hidden li span { display: flex; flex-direction: column; min-width: 0; }
.ws-hidden small { color: var(--muted); font-size: var(--fs-sm); }

.ws-guest {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  align-self: flex-start;
  min-height: 32px;
  padding: 0.2rem 0.6rem;
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  background: var(--ink-4);
  color: var(--muted-2);
  font-family: var(--font-body);
  font-size: var(--fs-sm);
  font-weight: 600;
  cursor: pointer;
}
.ws-guest .ico-svg { width: 15px; height: 15px; }
.ws-guest.on { background: var(--green-soft); border-color: var(--green-line); color: var(--green-dark); }
.ws-guest:hover { border-color: var(--primary); }

.ws-preview { margin-top: 1.25rem; }
.ws-preview-tools { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.ws-preview-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  margin-bottom: 0.6rem;
}
.ws-preview-head h3 { margin: 0; }
.ws-preview-head p { margin: 0.15rem 0 0; }
.ws-stage {
  position: relative;
  overflow: hidden;
  background: var(--surface-2);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-lg);
}
.ws-stage iframe {
  position: absolute;
  top: 0;
  left: 50%;
  translate: -50% 0;
  transform-origin: top center;
  border: 0;
  background: var(--bg);
}

/* Aksi selalu terjangkau walau pratinjau panjang */
.ws-foot {
  position: sticky;
  bottom: 0;
  z-index: 3;
  background: var(--surface);
  padding-bottom: 0.6rem;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem 1rem;
  margin-top: 1rem;
  padding-top: 0.8rem;
  border-top: 1px solid var(--border);
}
.ws-actions { display: inline-flex; flex-wrap: wrap; gap: 0.5rem; }
.ws-open { font-weight: 600; color: var(--primary); }

/* Layar sempit: kanvas jadi 1 kolom (sama dgn halaman asli di bawah 1180px) */
@media (max-width: 720px) {
  .ws-block { grid-column: span 12; }
}
@media (prefers-reduced-motion: reduce) {
  .ws-block { transition: none; }
}
</style>
