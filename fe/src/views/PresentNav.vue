<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import {
  PRESENT_SLIDES, PRESENT_MODULES, currentModulePath, slideIdx, slideTitle,
  gotoSlide, gotoModule, nextSlide, prevSlide, liveMode, setLive, nudgeLive,
} from '../stores/present'
import { cinema, presentStyle, stopCinematic, type PresentStyle } from '../stores/cinema'

/* ==========================================================================
   PresentNav: kapsul navigasi deck Present Mode.
   - Auto-sembunyi: tanpa interaksi IDLE_MS -> turun & hilang. Muncul lagi
     saat kursor mendekati tepi bawah (REVEAL_ZONE px), tombol keyboard,
     atau sentuhan di bagian bawah layar. Tetap tampil selama kursor di atas
     kapsul, fokus keyboard di dalamnya, atau menu modul terbuka.
   - Saat tersembunyi, kapsul tetap fokusabel (Tab memunculkannya kembali);
     garis petunjuk kecil di tepi bawah menandai letaknya.
   - Pilih modul = menu custom (bukan <select> bawaan) agar ikut gaya app.
   ========================================================================== */

const IDLE_MS = 2500
const REVEAL_ZONE = 120

const shown = ref(true)
const hovering = ref(false)
const focusedIn = ref(false)
const menuOpen = ref(false)
let timer = 0

const pinned = computed(() => hovering.value || focusedIn.value || menuOpen.value)

function scheduleHide(): void {
  window.clearTimeout(timer)
  if (pinned.value) return
  timer = window.setTimeout(() => {
    if (!pinned.value) shown.value = false
  }, IDLE_MS)
}
function reveal(): void {
  shown.value = true
  scheduleHide()
}
watch(pinned, (p) => {
  if (p) {
    shown.value = true
    window.clearTimeout(timer)
  } else scheduleHide()
})

// Pembuka sinematik mulai -> kapsul turun agar panggung bersih (kursor ke
// bawah tetap memunculkannya)
watch(
  () => cinema.run,
  () => {
    if (!pinned.value) {
      window.clearTimeout(timer)
      shown.value = false
    }
  },
)

function onPointerMove(e: PointerEvent): void {
  if (e.clientY >= window.innerHeight - REVEAL_ZONE) reveal()
}
function onPointerDown(e: PointerEvent): void {
  // Layar sentuh tidak punya hover: sentuhan di seperempat bawah memunculkan nav
  if (e.pointerType !== 'mouse' && e.clientY >= window.innerHeight * 0.75) reveal()
}
function onKey(e: KeyboardEvent): void {
  if (e.key !== 'Escape') reveal()
}

onMounted(() => {
  window.addEventListener('pointermove', onPointerMove, { passive: true })
  window.addEventListener('pointerdown', onPointerDown, { passive: true })
  window.addEventListener('keydown', onKey)
  scheduleHide()
})
onUnmounted(() => {
  window.clearTimeout(timer)
  window.removeEventListener('pointermove', onPointerMove)
  window.removeEventListener('pointerdown', onPointerDown)
  window.removeEventListener('keydown', onKey)
})

/* ---------- Menu modul ---------- */
const modules = computed(() =>
  PRESENT_MODULES.value.map((m) => ({
    ...m,
    count: PRESENT_SLIDES.value.filter((s) => s.path === m.path).length,
  })),
)
const currentModule = computed(
  () => modules.value.find((m) => m.path === currentModulePath.value) ?? modules.value[0],
)
const root = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)
const items = ref<HTMLButtonElement[]>([])

async function openMenu(): Promise<void> {
  menuOpen.value = true
  await nextTick()
  const i = Math.max(0, modules.value.findIndex((m) => m.path === currentModulePath.value))
  items.value[i]?.focus()
}
function closeMenu(focusTrigger = true): void {
  if (!menuOpen.value) return
  menuOpen.value = false
  if (focusTrigger) trigger.value?.focus()
}
function pick(path: string): void {
  gotoModule(path)
  closeMenu()
}
function onMenuKey(e: KeyboardEvent): void {
  const list = items.value
  const i = list.indexOf(document.activeElement as HTMLButtonElement)
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault()
    e.stopPropagation()
    const n = list.length
    list[(i + (e.key === 'ArrowDown' ? 1 : -1) + n) % n]?.focus()
  } else if (e.key === 'Home' || e.key === 'End') {
    e.preventDefault()
    list[e.key === 'Home' ? 0 : list.length - 1]?.focus()
  } else if (e.key === 'Escape') {
    e.stopPropagation() // tutup menu saja, jangan keluar Present Mode
    closeMenu()
  } else if (e.key === 'Tab') {
    closeMenu(false)
  } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
    e.stopPropagation() // panah kiri/kanan tidak pindah slide saat di menu
  }
}
function onDocPointer(e: PointerEvent): void {
  if (menuOpen.value && root.value && !root.value.contains(e.target as Node)) closeMenu(false)
}
onMounted(() => document.addEventListener('pointerdown', onDocPointer))
onUnmounted(() => document.removeEventListener('pointerdown', onDocPointer))

function onFocusOut(e: FocusEvent): void {
  if (!root.value?.contains(e.relatedTarget as Node | null)) {
    focusedIn.value = false
    closeMenu(false)
  }
}

/* Mode Live: Biasa | Cinematic. Loop Live dibangunkan agar langsung pakai
   mode baru (Cinematic memutar halaman ini; Biasa menutup panggung). */
function setStyle(v: PresentStyle): void {
  if (presentStyle.value === v) return
  presentStyle.value = v
  if (v === 'biasa') stopCinematic()
  nudgeLive()
}

/* Titik slide: dikelompokkan per modul (jarak antar grup) */
const groups = computed(() => {
  const out: { path: string; slides: { i: number; title: string }[] }[] = []
  PRESENT_SLIDES.value.forEach((s, i) => {
    const last = out[out.length - 1]
    if (last && last.path === s.path) last.slides.push({ i, title: s.title })
    else out.push({ path: s.path, slides: [{ i, title: s.title }] })
  })
  return out
})
</script>

<template>
  <div class="pn-wrap">
    <!-- Garis petunjuk saat kapsul tersembunyi -->
    <Transition name="pn-hint">
      <button
        v-if="!shown"
        type="button"
        class="pn-hint"
        aria-label="Tampilkan navigasi slide"
        @click="reveal"
      />
    </Transition>

    <nav
      ref="root"
      class="present-nav"
      :class="{ hidden: !shown }"
      aria-label="Navigasi slide"
      @pointerenter="hovering = true"
      @pointerleave="hovering = false"
      @focusin="focusedIn = true"
      @focusout="onFocusOut"
    >
      <!-- Pilih modul -->
      <div class="pn-menu-wrap">
        <button
          ref="trigger"
          type="button"
          class="pn-modul"
          aria-haspopup="menu"
          :aria-expanded="menuOpen"
          @click="menuOpen ? closeMenu() : openMenu()"
        >
          <span class="pn-modul-label">{{ currentModule?.label }}</span>
          <svg class="pn-chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 15l6-6 6 6" /></svg>
        </button>
        <Transition name="pn-pop">
          <div v-if="menuOpen" class="pn-pop" role="menu" aria-label="Pilih modul" @keydown="onMenuKey">
            <button
              v-for="(m, mi) in modules"
              :key="m.path"
              :ref="(el) => { if (el) items[mi] = el as HTMLButtonElement }"
              type="button"
              role="menuitemradio"
              class="pn-item"
              :class="{ on: m.path === currentModulePath }"
              :aria-checked="m.path === currentModulePath"
              @click="pick(m.path)"
            >
              <span class="pn-item-label">{{ m.label }}</span>
              <span class="pn-item-count num">{{ m.count }} slide</span>
              <svg v-if="m.path === currentModulePath" class="pn-check" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M5 12.5l4.5 4.5L19 7.5" />
              </svg>
            </button>
          </div>
        </Transition>
      </div>

      <span class="pn-sep" aria-hidden="true" />

      <button
        type="button" class="pn-btn" :disabled="slideIdx === 0"
        aria-label="Slide sebelumnya" @click="prevSlide"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 6l-6 6 6 6" /></svg>
      </button>

      <span class="pn-dots">
        <span v-for="g in groups" :key="g.path" class="pn-group">
          <button
            v-for="s in g.slides"
            :key="s.i"
            type="button"
            class="pn-dot"
            :class="{ on: s.i === slideIdx, done: s.i < slideIdx }"
            :aria-label="`Slide ${s.i + 1}: ${s.title}`"
            :aria-current="s.i === slideIdx ? 'step' : undefined"
            :title="s.title"
            @click="gotoSlide(s.i)"
          />
        </span>
      </span>

      <button
        type="button" class="pn-btn" :disabled="slideIdx >= PRESENT_SLIDES.length - 1"
        aria-label="Slide berikutnya" @click="nextSlide"
      >
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
      </button>

      <span class="pn-sep" aria-hidden="true" />

      <!-- Live: carousel otomatis (lihat stores/present.ts) -->
      <button
        type="button"
        class="pn-live"
        :class="{ on: liveMode }"
        :aria-pressed="liveMode"
        :aria-label="liveMode ? 'Matikan Live Mode' : 'Aktifkan Live Mode'"
        @click="setLive(!liveMode)"
      ><span class="live-dot" aria-hidden="true" />Live</button>

      <!-- Mode Live: muncul (bergeser keluar) saat Live dinyalakan -->
      <Transition name="pn-reveal">
        <div v-if="liveMode" class="pn-style" :class="presentStyle" role="group" aria-label="Mode Live">
          <span class="pn-style-ind" aria-hidden="true" />
          <button type="button" :aria-pressed="presentStyle === 'biasa'" @click="setStyle('biasa')">Biasa</button>
          <button type="button" :aria-pressed="presentStyle === 'cinematic'" @click="setStyle('cinematic')">Cinematic</button>
        </div>
      </Transition>

      <span class="pn-meta">
        <span class="pn-count num">{{ slideIdx + 1 }}<span class="pn-of">/{{ PRESENT_SLIDES.length }}</span></span>
        <Transition name="pn-title" mode="out-in">
          <span :key="slideTitle" class="pn-title">{{ slideTitle }}</span>
        </Transition>
      </span>
    </nav>
  </div>
</template>

<style scoped>
/* Kapsul gelap melayang: satu-satunya permukaan gelap + blur di aplikasi */
.present-nav {
  /* Warna dari token tema CMS: kapsul = --ink, teks = --bg */
  --pn-bg: color-mix(in srgb, var(--ink) 88%, transparent);
  --pn-line: color-mix(in srgb, var(--bg) 13%, transparent);
  --pn-soft: color-mix(in srgb, var(--bg) 9%, transparent);
  --pn-soft-2: color-mix(in srgb, var(--bg) 17%, transparent);
  --pn-text: var(--bg);
  --pn-muted: color-mix(in srgb, var(--bg) 62%, transparent);
  position: fixed;
  left: 50%;
  bottom: 20px;
  z-index: 60;
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  max-width: calc(100vw - 24px);
  padding: 6px 8px 6px 6px;
  border-radius: 999px;
  background: var(--pn-bg);
  color: var(--pn-text);
  border: 1px solid var(--pn-line);
  box-shadow: 0 20px 48px -16px rgba(0, 0, 0, 0.45), 0 2px 6px rgba(0, 0, 0, 0.18);
  backdrop-filter: blur(14px) saturate(140%);
  -webkit-backdrop-filter: blur(14px) saturate(140%);
  font-family: var(--font-body);
  font-size: var(--fs-sm);
  font-weight: 500;
  transform: translate(-50%, 0);
  opacity: 1;
  transition:
    transform 0.42s cubic-bezier(0.22, 1, 0.36, 1),
    opacity 0.3s ease;
  animation: pn-enter 0.5s cubic-bezier(0.22, 1, 0.36, 1) both;
}
.present-nav.hidden {
  transform: translate(-50%, calc(100% + 32px));
  opacity: 0;
  pointer-events: none;
  transition:
    transform 0.5s cubic-bezier(0.55, 0, 0.75, 0.2),
    opacity 0.35s ease 0.1s;
}
@keyframes pn-enter {
  from { transform: translate(-50%, 24px); opacity: 0; }
}

.pn-sep { width: 1px; height: 20px; background: var(--pn-line); flex: 0 0 auto; }

/* Tombol bulat ‹ › */
.pn-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--pn-text);
  cursor: pointer;
  transition: background 0.15s ease, transform 0.15s ease;
}
.pn-btn svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
.pn-btn:hover:not(:disabled) { background: var(--pn-soft-2); }
.pn-btn:active:not(:disabled) { transform: scale(0.92); }
.pn-btn:disabled { opacity: 0.28; cursor: default; }

/* Titik slide: grup per modul; aktif memanjang, yang sudah lewat lebih terang */
.pn-dots { display: inline-flex; align-items: center; gap: 10px; padding: 0 2px; }
.pn-group { display: inline-flex; align-items: center; gap: 5px; }
.pn-dot {
  width: 6px;
  height: 6px;
  padding: 0;
  border: 0;
  border-radius: 999px;
  background: color-mix(in srgb, var(--bg) 28%, transparent);
  cursor: pointer;
  transition: width 0.35s cubic-bezier(0.22, 1, 0.36, 1), background 0.25s ease;
}
.pn-dot.done { background: color-mix(in srgb, var(--bg) 55%, transparent); }
.pn-dot:hover { background: color-mix(in srgb, var(--bg) 80%, transparent); }
.pn-dot.on { width: 22px; background: var(--bg); }

/* Pemicu menu modul */
.pn-menu-wrap { position: relative; flex: 0 1 auto; min-width: 0; }
.pn-modul {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  max-width: 15rem;
  min-height: 34px;
  padding: 0 0.75rem 0 0.9rem;
  border: 0;
  border-radius: 999px;
  background: var(--pn-soft);
  color: var(--pn-text);
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s ease;
}
.pn-modul:hover,
.pn-modul[aria-expanded='true'] { background: var(--pn-soft-2); }
.pn-modul-label { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.pn-chev {
  width: 14px; height: 14px; flex: 0 0 auto;
  fill: none; stroke: currentColor; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round;
  opacity: 0.7;
  transition: transform 0.25s ease;
}
.pn-modul[aria-expanded='true'] .pn-chev { transform: rotate(180deg); }

/* Menu: kartu terang di atas kapsul (gaya panel app) */
.pn-pop {
  position: absolute;
  left: 0;
  bottom: calc(100% + 12px);
  width: max-content;
  min-width: 16rem;
  max-width: min(24rem, calc(100vw - 24px));
  padding: 6px;
  border-radius: 14px;
  background: var(--surface);
  color: var(--ink);
  border: 1px solid var(--border-strong);
  box-shadow: var(--shadow-raised);
  display: flex;
  flex-direction: column;
  gap: 2px;
  transform-origin: bottom left;
}
.pn-item {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto 16px;
  align-items: center;
  gap: 1.25rem;
  min-height: 40px;
  padding: 0.4rem 0.6rem 0.4rem 0.75rem;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--ink);
  font: inherit;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s ease;
}
.pn-item:hover,
.pn-item:focus-visible { background: var(--surface-2); outline: none; }
.pn-item.on { color: var(--primary); font-weight: 600; }
.pn-item-label { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pn-item-count { font-size: var(--fs-sm); font-weight: 400; color: var(--muted); white-space: nowrap; }
.pn-check { grid-column: 3; width: 16px; height: 16px; fill: none; stroke: var(--primary); stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; }

.pn-pop-enter-active { transition: opacity 0.18s ease, transform 0.22s cubic-bezier(0.22, 1, 0.36, 1); }
.pn-pop-leave-active { transition: opacity 0.12s ease, transform 0.12s ease; }
.pn-pop-enter-from,
.pn-pop-leave-to { opacity: 0; transform: translateY(6px) scale(0.97); }

/* Toggle mode tampilan: indikator putih bergeser antar pilihan */
.pn-style {
  position: relative;
  display: grid;
  grid-template-columns: 1fr 1fr;
  flex: 0 0 auto;
  padding: 3px;
  border-radius: 999px;
  background: var(--pn-soft);
}
.pn-style-ind {
  position: absolute;
  top: 3px;
  bottom: 3px;
  left: 3px;
  width: calc(50% - 3px);
  border-radius: 999px;
  background: var(--pn-text);
  transition: transform 0.35s cubic-bezier(0.22, 1, 0.36, 1);
}
.pn-style.cinematic .pn-style-ind { transform: translateX(100%); }
.pn-style button {
  position: relative;
  z-index: 1;
  min-height: 28px;
  padding: 0 0.75rem;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--pn-muted);
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition: color 0.25s ease;
}
.pn-style button:hover { color: var(--pn-text); }
.pn-style button[aria-pressed='true'] { color: var(--ink); }
.pn-reveal-enter-active, .pn-reveal-leave-active {
  transition: max-width 0.45s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.3s ease, margin 0.45s ease;
  overflow: hidden;
}
.pn-style { max-width: 220px; }
.pn-reveal-enter-from, .pn-reveal-leave-to { max-width: 0; opacity: 0; margin-left: -0.5rem; }

/* Live: titik berdenyut saat aktif */
.pn-live {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  min-height: 34px;
  padding: 0 0.85rem;
  border: 0;
  border-radius: 999px;
  background: var(--pn-soft);
  color: var(--pn-text);
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s ease, color 0.2s ease;
}
.pn-live:hover { background: var(--pn-soft-2); }
.pn-live .live-dot {
  position: relative;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: color-mix(in srgb, var(--bg) 45%, transparent);
  transition: background 0.2s ease;
}
.pn-live.on { background: color-mix(in srgb, var(--green) 26%, transparent); color: color-mix(in srgb, var(--green) 45%, var(--bg)); }
.pn-live.on .live-dot { background: color-mix(in srgb, var(--green) 75%, var(--bg)); }
.pn-live.on .live-dot::after {
  content: '';
  position: absolute;
  inset: -4px;
  border-radius: 50%;
  border: 1.5px solid color-mix(in srgb, var(--green) 75%, var(--bg));
  animation: pn-pulse 1.6s ease-out infinite;
}
@keyframes pn-pulse {
  from { transform: scale(0.5); opacity: 0.9; }
  to { transform: scale(1.8); opacity: 0; }
}

/* Penghitung + judul slide */
.pn-meta { display: inline-flex; align-items: baseline; gap: 0.6rem; min-width: 0; padding-right: 0.4rem; }
.pn-count { font-weight: 600; white-space: nowrap; font-variant-numeric: tabular-nums; }
.pn-of { color: var(--pn-muted); font-weight: 500; }
.pn-title {
  display: inline-block;
  max-width: 14rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--pn-muted);
}
.pn-title-enter-active,
.pn-title-leave-active { transition: opacity 0.2s ease, transform 0.2s ease; }
.pn-title-enter-from { opacity: 0; transform: translateY(6px); }
.pn-title-leave-to { opacity: 0; transform: translateY(-6px); }

/* Garis petunjuk saat tersembunyi */
.pn-hint {
  position: fixed;
  left: 50%;
  bottom: 8px;
  z-index: 59;
  width: 120px;
  height: 18px;
  padding: 0;
  border: 0;
  background: transparent;
  transform: translateX(-50%);
  cursor: pointer;
}
.pn-hint::before {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  top: 7px;
  height: 4px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--ink) 28%, transparent);
  transition: background 0.2s ease;
}
.pn-hint:hover::before { background: color-mix(in srgb, var(--ink) 50%, transparent); }
.pn-hint-enter-active { transition: opacity 0.4s ease 0.3s; }
.pn-hint-leave-active { transition: opacity 0.15s ease; }
.pn-hint-enter-from,
.pn-hint-leave-to { opacity: 0; }

.present-nav :focus-visible { outline: 2px solid var(--bg); outline-offset: 2px; }
.pn-pop :focus-visible { outline: none; }

@media (max-width: 720px) {
  .pn-title, .pn-dots { display: none; }
  .present-nav { bottom: 12px; }
  .pn-modul { max-width: 9rem; }
}
@media (max-width: 520px) {
  .pn-style button { padding: 0 0.5rem; }
}
@media (max-width: 420px) {
  .pn-sep { display: none; }
  .pn-live { padding: 0 0.65rem; }
}
@media (prefers-reduced-motion: reduce) {
  .present-nav,
  .present-nav.hidden { transition: opacity 0.2s ease; animation: none; }
  .present-nav.hidden { transform: translate(-50%, 0); }
  .pn-dot, .pn-chev, .pn-style-ind { transition: none; }
  .pn-reveal-enter-active, .pn-reveal-leave-active { transition: opacity 0.15s ease; }
  .pn-live.on .live-dot::after { animation: none; display: none; }
  .pn-pop-enter-active, .pn-pop-leave-active,
  .pn-title-enter-active, .pn-title-leave-active { transition: opacity 0.1s ease; }
  .pn-pop-enter-from, .pn-pop-leave-to,
  .pn-title-enter-from, .pn-title-leave-to { transform: none; }
}
</style>
