<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { cinema, pageDone } from '../stores/cinema'
import { PRESENT_SLIDES, slideIdx, slideTitle } from '../stores/present'
import { bankName } from '../stores/branding'
import { dateLabel, sysDate } from '../pby-helpers'
import { lineChartByEl } from './LineChart.vue'

/* ==========================================================================
   CinematicStage: panggung Live mode Cinematic.
   Tiap halaman = rangkaian adegan:
     1. Pembuka : judul (per kata), angka utama berhitung naik, angka
                  pendukung, chip pertumbuhan, sparkline.
     2. Panel   : 1 adegan per panel data halaman (grafik/tabel/komposisi).
                  Panel ASLI disalin (cloneNode, gaya scoped ikut) jadi kartu
                  melayang; panel panjang digeser pelan seperti kamera.
   Sesudah adegan terakhir -> pageDone() -> Live pindah halaman, panggung
   tetap terbuka (halaman berikutnya dimuat di balik tirai).
   SUMBER = DOM halaman yg sudah dimuat (hasil query yg sama). Tidak ada
   angka buatan. Klik / Enter / Spasi = adegan berikutnya.
   WARNA = token tema CMS: latar dari --ink, teks dari --bg, cahaya dari
   --primary/--accent, kartu dari --surface, naik/turun dari --green/--red.
   ========================================================================== */

interface Num { pre: string; suf: string; val: number; dec: number; dotDec: boolean }
interface Stat { label: string; sub: string; text: string; tone: '' | 'up' | 'down'; num: Num | null }
interface Hero { label: string; text: string; note: string; chip: string; chipTone: string; num: Num | null }
interface IntroScene { kind: 'intro'; title: string; sub: string; hero: Hero | null; stats: Stat[]; spark: string }
interface PanelScene { kind: 'panel'; title: string; sub: string; node: HTMLElement; width: number }
type Scene = IntroScene | PanelScene

const phase = ref<'idle' | 'wait' | 'show' | 'leave'>('idle')
const scenes = ref<Scene[]>([])
const sceneIdx = ref(0)
const sceneDur = ref(0) // ms, utk bar progres adegan
const heroShown = ref('')
const statShown = reactive<string[]>([])
const tgl = ref<string | null>(null)
const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false

let token = 0
let timers: number[] = []
let rafs: number[] = []
let anims: Animation[] = []
let advance: (() => void) | null = null
const later = (ms: number, fn: () => void): void => {
  timers.push(window.setTimeout(fn, ms))
}
function clearAll(): void {
  timers.forEach((t) => window.clearTimeout(t))
  rafs.forEach((r) => cancelAnimationFrame(r))
  anims.forEach((a) => a.cancel())
  timers = []
  rafs = []
  anims = []
}
const sleep = (ms: number): Promise<void> => new Promise((r) => later(ms, r))

/* ---------- Angka ---------- */
function parseNum(text: string): Num | null {
  const m = text.match(/^(.*?)(-?\d[\d.,]*\d|\d)(.*)$/)
  if (!m) return null
  const [, pre, raw, suf] = m
  if (/^-?\d+\.\d{1,2}$/.test(raw)) {
    return { pre, suf, val: parseFloat(raw), dec: raw.split('.')[1].length, dotDec: true }
  }
  const dec = raw.includes(',') ? raw.split(',')[1].length : 0
  const val = parseFloat(raw.replace(/\./g, '').replace(',', '.'))
  return Number.isFinite(val) ? { pre, suf, val, dec, dotDec: false } : null
}
function fmtNum(n: Num, v: number): string {
  const body = n.dotDec
    ? v.toFixed(n.dec)
    : v.toLocaleString('id-ID', { minimumFractionDigits: n.dec, maximumFractionDigits: n.dec })
  return `${n.pre}${body}${n.suf}`
}
function countUp(n: Num | null, final: string, delay: number, dur: number, set: (s: string) => void): void {
  if (!n || reduce) {
    later(delay, () => set(final))
    return
  }
  set(fmtNum(n, 0))
  later(delay, () => {
    const t0 = performance.now()
    const step = (t: number): void => {
      const p = Math.min(1, (t - t0) / dur)
      set(p < 1 ? fmtNum(n, n.val * (1 - Math.pow(2, -10 * p))) : final)
      if (p < 1) rafs.push(requestAnimationFrame(step))
    }
    rafs.push(requestAnimationFrame(step))
  })
}

/* ---------- Baca halaman ---------- */
const txt = (el: Element | null | undefined): string => (el?.textContent ?? '').replace(/\s+/g, ' ').trim()
const outsidePanel = (el: Element): boolean => !el.closest('.panel')

async function waitPage(t: number): Promise<Element | null> {
  const t0 = performance.now()
  const expect = slideTitle.value
  let opened = false
  for (;;) {
    if (t !== token) return null
    const el = performance.now() - t0
    const main = document.querySelector('.main')
    const h1 = txt(main?.querySelector('.page-head h1'))
    const titleOk = !!h1 && (h1 === expect || el > 2500)
    const busy = !!main && /Memuat/.test(main.textContent ?? '')
    if (main && titleOk && !busy && el > 600) {
      // Tabel terperinci ("More details") dibuka dulu agar ikut tampil
      const closed = [...main.querySelectorAll<HTMLButtonElement>('.details-btn[aria-expanded="false"]')]
      if (closed.length && !opened) {
        opened = true
        closed.forEach((b) => b.click())
        await sleep(700)
        continue
      }
      await sleep(250) // biar grafik asli selesai menata ukuran
      return main
    }
    if (main && el > 10000) return main
    await sleep(150)
  }
}

function readIntro(main: Element): IntroScene {
  const heroEl = [...main.querySelectorAll('.lead-value')].find(outsidePanel)
  let hero: Hero | null = null
  if (heroEl) {
    const box = heroEl.closest('.lead-part, .lead') ?? heroEl.parentElement!
    const noteEl = box.querySelector('.lead-note')
    const chipEl = noteEl?.querySelector('.chip')
    const chip = txt(chipEl)
    const text = txt(heroEl)
    hero = {
      label: txt(box.querySelector('.lead-label')),
      text,
      note: txt(noteEl).replace(chip, '').trim(),
      chip,
      chipTone: chipEl?.classList.contains('down') ? 'down' : chipEl?.classList.contains('up') ? 'up' : '',
      num: text && text !== '–' ? parseNum(text) : null,
    }
  }
  const stats: Stat[] = [...main.querySelectorAll('.ledger > div')]
    .filter(outsidePanel)
    .slice(0, 4)
    .map((div) => {
      const dt = div.querySelector('dt')
      const label = [...(dt?.childNodes ?? [])]
        .filter((n) => n.nodeType === Node.TEXT_NODE)
        .map((n) => n.textContent ?? '')
        .join(' ')
        .replace(/\s+/g, ' ')
        .trim()
      const dd = div.querySelector('dd')
      const text = txt(dd)
      return {
        label,
        sub: txt(dt?.querySelector('small')),
        text,
        tone: dd?.classList.contains('g-up') ? 'up' : dd?.classList.contains('g-down') ? 'down' : '',
        num: text && text !== '–' ? parseNum(text) : null,
      }
    })
  const poly = [...main.querySelectorAll('.lead-spark polyline')].find(outsidePanel)
  // Sparkline asli (viewBox 100x28) diskala x4 -> proporsi tetap, garis mulus
  const spark = (poly?.getAttribute('points') ?? '')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((pt) => pt.split(',').map((v) => (Number(v) * 4).toFixed(1)).join(','))
    .join(' ')
  return {
    kind: 'intro',
    title: txt(main.querySelector('.page-head h1')) || slideTitle.value,
    sub: txt(main.querySelector('.page-head p')),
    hero,
    stats,
    spark,
  }
}

/** Panel data tampil, urut posisi visual (grid widget memakai CSS order). */
function readPanels(main: Element): PanelScene[] {
  return [...main.querySelectorAll<HTMLElement>('.panel')]
    .filter((p) => p.offsetParent !== null && !p.parentElement?.closest('.panel'))
    .map((p) => ({ p, r: p.getBoundingClientRect() }))
    .filter(({ r }) => r.width > 0 && r.height > 0)
    .sort((a, b) => a.r.top - b.r.top || a.r.left - b.r.left)
    .map(({ p, r }) => {
      const head = p.querySelector(':scope > h2, :scope > .pby-head h2, :scope h2')
      const subEl = p.querySelector(':scope > .sub, :scope > .pby-head .sub')
      const node = p.cloneNode(true) as HTMLElement
      // Grafik TradingView: canvas tak ikut tersalin -> ganti gambar hasil snapshot
      const srcHosts = [...p.querySelectorAll<HTMLElement>('.lc-host')]
      const dstHosts = [...node.querySelectorAll<HTMLElement>('.lc-host')]
      srcHosts.forEach((src, i) => {
        const chart = lineChartByEl.get(src)
        const dst = dstHosts[i]
        if (!chart || !dst) return
        const img = document.createElement('img')
        img.alt = dst.getAttribute('aria-label') ?? ''
        img.src = chart.takeScreenshot().toDataURL('image/png')
        img.style.width = '100%'
        img.style.height = `${src.clientHeight}px`
        dst.replaceWith(img)
      })
      node.setAttribute('inert', '')
      node.classList.add('cine-clone')
      // Kontrol (toggle/filter/tombol) tidak berarti di panggung
      node
        .querySelectorAll('.pby-ctrl, .details-btn, .pby-pager, .pager, .filters, .compare-actions')
        .forEach((c) => c.remove())
      return { kind: 'panel' as const, title: txt(head) || 'Rincian', sub: txt(subEl), node, width: Math.round(r.width) }
    })
}

/* ---------- Pemutaran ---------- */
const INTRO_HERO = 7400
const INTRO_TITLE = 3800

function waitAdvance(ms: number): Promise<void> {
  return new Promise((resolve) => {
    let done = false
    const go = (): void => {
      if (done) return
      done = true
      advance = null
      resolve()
    }
    advance = go
    later(ms, go)
  })
}

async function playIntro(s: IntroScene): Promise<void> {
  heroShown.value = ''
  statShown.splice(0, statShown.length, ...s.stats.map(() => ''))
  const dur = reduce ? 3200 : s.hero ? INTRO_HERO : INTRO_TITLE
  sceneDur.value = dur
  if (s.hero) countUp(s.hero.num, s.hero.text, 1500, 1900, (v) => (heroShown.value = v))
  s.stats.forEach((st, i) => countUp(st.num, st.text, 2800 + i * 260, 1300, (v) => (statShown[i] = v)))
  await waitAdvance(dur)
}

async function playPanel(s: PanelScene, t: number, key: string): Promise<void> {
  // Tunggu kartu MILIK adegan ini terpasang (Transition out-in: kartu adegan
  // sebelumnya masih ada selama memudar keluar)
  let c: HTMLElement | null = null
  for (let i = 0; i < 80 && t === token; i++) {
    c = document.querySelector<HTMLElement>(`.cp-card[data-k="${key}"]`)
    if (c) break
    await sleep(25)
  }
  const box = c?.parentElement ?? null
  if (!box || !c || t !== token) return
  c.replaceChildren(s.node)
  c.style.width = `${s.width}px`
  await nextTick()
  // Tabel lebar di halaman digulir horizontal; di panggung semua kolom harus
  // terlihat -> kartu dilebarkan sebesar bagian tabel yg tersembunyi
  const extra = Math.max(
    0,
    ...[...s.node.querySelectorAll<HTMLElement>('.table-scroll')].map((el) => el.scrollWidth - el.clientWidth),
  )
  const cw = s.width + extra
  c.style.width = `${cw}px`
  await nextTick()
  const vw = box.clientWidth
  const vh = box.clientHeight
  const ch = c.scrollHeight
  // Lebar kartu = lebar panel asli (tata letak tabel tetap); skala muat layar
  const fitW = Math.min(1.25, vw / cw)
  const scale = reduce ? Math.min(fitW, vh / ch) : fitW
  const pan = Math.max(0, ch * scale - vh + 32)
  const panMs = reduce ? 0 : Math.min(16000, (pan / 70) * 1000)
  const enter = 1000
  const holdA = pan > 0 ? 1400 : 3600
  const holdB = 1800
  sceneDur.value = enter + holdA + panMs + holdB
  const x = Math.round((vw - cw * scale) / 2)
  const rest = `translate(${x}px, 0px) scale(${scale})`
  c.style.transformOrigin = '0 0'
  c.style.transform = rest
  if (!reduce) {
    anims.push(
      c.animate(
        [
          { opacity: 0, transform: `translate(${x}px, 48px) scale(${scale * 0.96}) perspective(1400px) rotateX(10deg)` },
          { opacity: 1, transform: `${rest} perspective(1400px) rotateX(0deg)` },
        ],
        { duration: enter, easing: 'cubic-bezier(0.22, 1, 0.36, 1)', fill: 'backwards' },
      ),
    )
    if (pan > 0) {
      anims.push(
        c.animate(
          [{ transform: rest }, { transform: `translate(${x}px, ${-pan}px) scale(${scale})` }],
          { duration: panMs, delay: enter + holdA, easing: 'cubic-bezier(0.45, 0, 0.55, 1)', fill: 'forwards' },
        ),
      )
    }
  }
  await waitAdvance(sceneDur.value)
}

async function playPage(): Promise<void> {
  clearAll()
  const t = ++token
  advance = null
  scenes.value = []
  sceneIdx.value = 0
  phase.value = 'wait'
  const main = await waitPage(t)
  if (t !== token || !main) return
  scenes.value = [readIntro(main), ...readPanels(main)]
  phase.value = 'show'
  for (let i = 0; i < scenes.value.length; i++) {
    if (t !== token) return
    sceneIdx.value = i
    const s = scenes.value[i]
    if (s.kind === 'intro') await playIntro(s)
    else await playPanel(s, t, `${cinema.run}-${i}`)
    if (t !== token) return
    clearAll()
  }
  phase.value = 'wait' // tirai tetap; halaman berikutnya dimuat di belakang
  pageDone()
}

function close(): void {
  clearAll()
  token++
  advance = null
  if (phase.value === 'idle') return
  phase.value = 'leave'
  later(900, () => {
    phase.value = 'idle'
    scenes.value = []
  })
}

watch(() => cinema.run, () => void playPage())
watch(
  () => cinema.active,
  (on) => {
    if (!on) close()
  },
)

function skip(): void {
  advance?.()
}
function onKey(e: KeyboardEvent): void {
  if (phase.value !== 'show') return
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    skip()
  }
}
onMounted(async () => {
  window.addEventListener('keydown', onKey)
  if (cinema.active) void playPage()
  tgl.value = await sysDate()
})
onUnmounted(() => {
  window.removeEventListener('keydown', onKey)
  clearAll()
  token++
})

const scene = computed(() => scenes.value[sceneIdx.value] ?? null)
const intro = computed(() => (scene.value?.kind === 'intro' ? scene.value : null))
const panel = computed(() => (scene.value?.kind === 'panel' ? scene.value : null))
const panelCount = computed(() => scenes.value.filter((s) => s.kind === 'panel').length)
const words = computed(() => (intro.value?.title ?? '').split(/\s+/).filter(Boolean))
const counter = computed(
  () => `${String(slideIdx.value + 1).padStart(2, '0')} / ${String(PRESENT_SLIDES.value.length).padStart(2, '0')}`,
)
</script>

<template>
  <Transition name="cine">
    <div
      v-if="phase !== 'idle'"
      class="cine"
      :class="phase"
      role="region"
      :aria-label="`Live cinematic: ${slideTitle}`"
      @click="skip"
    >
      <div class="cine-bg" aria-hidden="true" />
      <div class="cine-grain" aria-hidden="true" />

      <div class="cine-bar top">
        <span class="cine-brand">{{ bankName }}<span class="cine-counter num">{{ counter }}</span></span>
        <Transition name="cine-swap" mode="out-in">
          <span :key="slideTitle" class="cine-page">{{ slideTitle }}</span>
        </Transition>
      </div>
      <div class="cine-bar bottom">
        <span class="cine-date">{{ tgl ? `Tanggal sistem ${dateLabel(tgl)}` : '' }}</span>
        <!-- Progres adegan halaman ini: 1 segmen per adegan -->
        <span v-if="scenes.length > 1" class="cine-prog" aria-hidden="true">
          <span v-for="(_, i) in scenes" :key="`${cinema.run}-${i}`" class="seg" :class="{ done: i < sceneIdx }">
            <span
              v-if="i === sceneIdx && phase === 'show'"
              :key="`f-${cinema.run}-${i}-${sceneDur}`"
              class="fill"
              :style="{ animationDuration: `${sceneDur}ms` }"
            />
          </span>
        </span>
        <span class="cine-skip">Klik atau Enter untuk adegan berikutnya</span>
      </div>

      <Transition name="cine-scene" mode="out-in">
        <!-- Menunggu halaman dimuat -->
        <div v-if="phase !== 'show' || !scene" key="wait" class="cine-wait" aria-hidden="true">
          <span class="cine-wait-title">{{ slideTitle }}</span>
          <span class="cine-loader" />
        </div>

        <!-- Adegan pembuka -->
        <div v-else-if="intro" :key="`intro-${cinema.run}`" class="cine-stage" aria-live="polite">
          <h1 class="cine-title">
            <span v-for="(w, i) in words" :key="i" class="cw"><span :style="{ '--d': `${0.25 + i * 0.09}s` }">{{ w }}</span></span>
          </h1>
          <p v-if="intro.sub" class="cine-sub">{{ intro.sub }}</p>

          <div v-if="intro.hero" class="cine-hero">
            <p class="cine-label">{{ intro.hero.label }}</p>
            <p class="cine-num num">{{ heroShown || ' ' }}</p>
            <span class="cine-rule" aria-hidden="true" />
            <p v-if="intro.hero.chip || intro.hero.note" class="cine-note">
              <span v-if="intro.hero.chip" class="cine-chip" :class="intro.hero.chipTone">{{ intro.hero.chip }}</span>
              {{ intro.hero.note }}
            </p>
            <svg v-if="intro.spark" class="cine-spark" viewBox="0 0 400 112" aria-hidden="true">
              <polyline :points="intro.spark" pathLength="1" />
            </svg>
          </div>

          <dl v-if="intro.stats.length" class="cine-stats">
            <div v-for="(s, i) in intro.stats" :key="i" :style="{ '--d': `${2.7 + i * 0.26}s` }">
              <dt>{{ s.label }}<small v-if="s.sub">{{ s.sub }}</small></dt>
              <dd class="num" :class="s.tone">{{ statShown[i] || ' ' }}</dd>
            </div>
          </dl>

          <p v-if="panelCount" class="cine-next">
            Selanjutnya {{ panelCount }} bagian data di halaman ini
          </p>
        </div>

        <!-- Adegan panel: salinan panel asli sbg kartu melayang -->
        <div v-else-if="panel" :key="`panel-${cinema.run}-${sceneIdx}`" class="cine-panel" aria-live="polite">
          <header class="cp-head">
            <span class="cp-step num">Bagian {{ sceneIdx }} dari {{ panelCount }}</span>
            <h2 class="cp-title">{{ panel.title }}</h2>
            <p v-if="panel.sub" class="cp-sub">{{ panel.sub }}</p>
          </header>
          <div class="cp-viewport">
            <div class="cp-card" :data-k="`${cinema.run}-${sceneIdx}`" />
          </div>
        </div>
      </Transition>
    </div>
  </Transition>
</template>

<style scoped>
/* Semua warna dari token tema CMS (stores/theme.ts menulis ke :root):
   panggung = --ink (warna teks tema, selalu kontras dgn --bg), teks = --bg. */
.cine {
  --c-ink: color-mix(in srgb, var(--ink) 94%, var(--primary));
  --c-bar: color-mix(in srgb, var(--ink) 55%, #000);
  --c-text: var(--bg);
  --c-muted: color-mix(in srgb, var(--bg) 62%, transparent);
  --c-line: color-mix(in srgb, var(--bg) 18%, transparent);
  --c-up: color-mix(in srgb, var(--green) 55%, var(--bg));
  --c-down: color-mix(in srgb, var(--red) 50%, var(--bg));
  --ease: cubic-bezier(0.22, 1, 0.36, 1);
  --bar-h: max(52px, 9vh);
  position: fixed;
  inset: 0;
  z-index: 58;
  overflow: hidden;
  color: var(--c-text);
  font-family: var(--font-body);
  cursor: pointer;
}
.cine-bg {
  position: absolute;
  inset: -10%;
  background:
    radial-gradient(60% 55% at 18% 78%, color-mix(in srgb, var(--primary) 55%, transparent), transparent 70%),
    radial-gradient(45% 40% at 85% 18%, color-mix(in srgb, var(--accent) 28%, transparent), transparent 70%),
    var(--c-ink);
  animation: cine-drift 14s ease-in-out infinite alternate;
}
@keyframes cine-drift {
  from { transform: scale(1) translate3d(0, 0, 0); }
  to { transform: scale(1.08) translate3d(-2%, 1.5%, 0); }
}
.cine-grain {
  position: absolute;
  inset: 0;
  opacity: 0.09;
  mix-blend-mode: overlay;
  pointer-events: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
}

/* Letterbox */
.cine-bar {
  position: absolute;
  left: 0;
  right: 0;
  z-index: 3;
  height: var(--bar-h);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.5rem;
  padding: 0 4vw;
  background: var(--c-bar);
  color: var(--c-muted);
  font-size: var(--fs-sm);
  transition: transform 0.8s var(--ease);
}
.cine-bar.top { top: 0; padding-right: calc(4vw + 170px); animation: bar-top 0.8s var(--ease) both; }
.cine-bar.bottom { bottom: 0; animation: bar-bottom 0.8s var(--ease) both; }
@keyframes bar-top { from { transform: translateY(-100%); } }
@keyframes bar-bottom { from { transform: translateY(100%); } }
.cine.leave .cine-bar.top { transform: translateY(-100%); }
.cine.leave .cine-bar.bottom { transform: translateY(100%); }
.cine-brand { display: inline-flex; align-items: center; gap: 1.25rem; white-space: nowrap; }
.cine-counter { padding-left: 1.25rem; border-left: 1px solid var(--c-line); color: var(--c-text); }
.cine-page { color: var(--c-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cine-date, .cine-skip { white-space: nowrap; }
.cine-swap-enter-active, .cine-swap-leave-active { transition: opacity 0.3s ease, transform 0.3s ease; }
.cine-swap-enter-from { opacity: 0; transform: translateY(8px); }
.cine-swap-leave-to { opacity: 0; transform: translateY(-8px); }

/* Progres adegan */
/* Progres adegan: garis tipis di TEPI ATAS footer (bukan di tengah footer,
   karena di situ kapsul navigasi Present Mode melayang -> dulu saling timpa) */
.cine-prog { position: absolute; left: 4vw; right: 4vw; top: 0; height: 3px; display: flex; gap: 6px; }
.cine-prog .seg { position: relative; flex: 1; height: 3px; border-radius: 3px; overflow: hidden; background: var(--c-line); }
.cine-prog .seg.done { background: var(--c-text); }
.cine-prog .fill {
  position: absolute;
  inset: 0;
  background: var(--accent);
  transform-origin: left;
  animation-name: prog;
  animation-timing-function: linear;
  animation-fill-mode: both;
}
@keyframes prog { from { transform: scaleX(0); } }

/* Menunggu data */
.cine-wait {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
}
.cine-wait-title { font-family: var(--font-display); font-size: clamp(2rem, 4vw, 3.5rem); color: var(--c-muted); }
.cine-loader { position: relative; width: 160px; height: 2px; overflow: hidden; background: var(--c-line); border-radius: 2px; }
.cine-loader::after {
  content: '';
  position: absolute;
  inset: 0;
  width: 40%;
  background: var(--c-text);
  animation: load 1.1s ease-in-out infinite;
}
@keyframes load { from { transform: translateX(-100%); } to { transform: translateX(250%); } }

/* Transisi antar adegan */
.cine-scene-enter-active { transition: opacity 0.5s ease, transform 0.7s var(--ease), filter 0.5s ease; }
.cine-scene-leave-active { transition: opacity 0.4s ease, transform 0.45s ease, filter 0.4s ease; }
.cine-scene-enter-from { opacity: 0; transform: scale(0.98); filter: blur(6px); }
.cine-scene-leave-to { opacity: 0; transform: scale(1.03); filter: blur(6px); }
.cine.leave .cine-stage,
.cine.leave .cine-panel,
.cine.leave .cine-wait { opacity: 0; transition: opacity 0.5s ease; }

/* ---- Adegan pembuka ---- */
.cine-stage {
  position: absolute;
  inset: var(--bar-h) 0;
  z-index: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 3vh 8vw;
}
.cine-title {
  margin: 0;
  font-family: var(--font-display);
  font-weight: 400;
  font-size: clamp(2.75rem, 6.4vw, 7rem);
  line-height: 1;
  letter-spacing: -0.015em;
  color: var(--c-text);
}
.cw { display: inline-block; overflow: hidden; vertical-align: bottom; padding-bottom: 0.08em; margin-right: 0.22em; }
.cw > span { display: inline-block; animation: rise 0.9s var(--ease) var(--d) both; }
@keyframes rise { from { transform: translateY(105%); } }
.cine-sub {
  margin: 1.1rem 0 0;
  max-width: 60ch;
  color: var(--c-muted);
  font-size: clamp(1rem, 1.2vw, 1.25rem);
  animation: fade-up 0.8s var(--ease) 0.85s both;
}
.cine-hero { margin-top: clamp(1.75rem, 6vh, 4rem); }
.cine-label { margin: 0 0 0.4rem; color: var(--c-muted); font-size: clamp(0.95rem, 1.1vw, 1.2rem); animation: fade-up 0.7s var(--ease) 1.3s both; }
.cine-num {
  margin: 0;
  font-size: clamp(3rem, 8.2vw, 9.5rem);
  font-weight: 200;
  line-height: 1;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  animation: fade-in 0.6s ease 1.4s both;
}
.cine-rule {
  display: block;
  height: 2px;
  margin-top: 1.25rem;
  width: min(42vw, 520px);
  background: linear-gradient(90deg, var(--accent), transparent);
  transform-origin: left;
  animation: draw-x 1.6s var(--ease) 1.7s both;
}
@keyframes draw-x { from { transform: scaleX(0); } }
.cine-note {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem;
  margin: 1rem 0 0;
  color: var(--c-muted);
  font-size: clamp(0.95rem, 1vw, 1.1rem);
  animation: fade-up 0.7s var(--ease) 2.4s both;
}
.cine-chip { padding: 0.15rem 0.7rem; border-radius: 999px; background: var(--c-line); color: var(--c-text); font-weight: 500; }
.cine-chip.up { background: color-mix(in srgb, var(--green) 22%, transparent); color: var(--c-up); }
.cine-chip.down { background: color-mix(in srgb, var(--red) 22%, transparent); color: var(--c-down); }
.cine-spark { display: block; width: min(34vw, 460px); height: auto; margin-top: 1.25rem; overflow: visible; }
.cine-spark polyline {
  fill: none;
  stroke: var(--accent);
  stroke-width: 3;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-dasharray: 1;
  stroke-dashoffset: 1;
  animation: draw-line 1.8s var(--ease) 2.1s forwards;
}
@keyframes draw-line { to { stroke-dashoffset: 0; } }
.cine-stats {
  position: relative;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1.25rem 3vw;
  margin: clamp(1.75rem, 5vh, 3.5rem) 0 0;
  padding-top: 1.5rem;
}
.cine-stats::before {
  content: '';
  position: absolute;
  inset: 0 0 auto;
  height: 1px;
  background: var(--c-line);
  transform-origin: left;
  animation: draw-x 1.2s var(--ease) 2.5s both;
}
.cine-stats > div { min-width: 0; animation: fade-up 0.8s var(--ease) var(--d) both; }
.cine-stats dt { color: var(--c-muted); font-size: clamp(0.9rem, 0.95vw, 1.05rem); }
.cine-stats dt small { display: block; font-size: 0.85em; opacity: 0.75; }
.cine-stats dd { margin: 0.35rem 0 0; font-size: clamp(1.4rem, 2.2vw, 2.4rem); font-weight: 300; letter-spacing: -0.02em; white-space: nowrap; font-variant-numeric: tabular-nums; }
.cine-stats dd.up { color: var(--c-up); }
.cine-stats dd.down { color: var(--c-down); }
.cine-next { margin: 2rem 0 0; color: var(--c-muted); font-size: var(--fs-sm); animation: fade-up 0.8s var(--ease) 4s both; }

/* ---- Adegan panel ---- */
.cine-panel {
  position: absolute;
  inset: var(--bar-h) 0;
  z-index: 1;
  display: flex;
  flex-direction: column;
  padding: 3.5vh 6vw 2.5vh;
  gap: 2.5vh;
}
.cp-head { flex: 0 0 auto; }
.cp-step { display: block; color: var(--c-muted); font-size: var(--fs-sm); animation: fade-up 0.6s var(--ease) 0.1s both; }
.cp-title {
  margin: 0.35rem 0 0;
  font-family: var(--font-display);
  font-weight: 400;
  font-size: clamp(2rem, 3.6vw, 3.75rem);
  line-height: 1.05;
  color: var(--c-text);
  animation: fade-up 0.8s var(--ease) 0.2s both;
}
.cp-sub { margin: 0.5rem 0 0; color: var(--c-muted); font-size: clamp(0.95rem, 1vw, 1.1rem); max-width: 80ch; animation: fade-up 0.8s var(--ease) 0.35s both; }
.cp-viewport {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
  overflow: hidden;
  /* Tepi atas & bawah memudar: kartu panjang "lewat" seperti kamera */
  -webkit-mask-image: linear-gradient(180deg, transparent 0, #000 2.5%, #000 92%, transparent 100%);
  mask-image: linear-gradient(180deg, transparent 0, #000 2.5%, #000 92%, transparent 100%);
}
.cp-card {
  position: absolute;
  top: 1rem;
  left: 0;
  border-radius: 20px;
  background: var(--surface);
  color: var(--text);
  box-shadow: 0 40px 90px -30px rgba(0, 0, 0, 0.7), 0 0 0 1px var(--c-line);
  will-change: transform;
  cursor: default;
}
/* Salinan panel: kartu sudah jadi wadah; judul tampil di panggung */
.cp-card :deep(.cine-clone) {
  margin: 0;
  border: 0;
  border-radius: 20px;
  animation: none;
}
.cp-card :deep(.cine-clone > h2),
.cp-card :deep(.cine-clone > .sub),
.cp-card :deep(.cine-clone .pby-head > div:first-child) { display: none; }
.cp-card :deep(.cine-clone .pby-head) { margin-bottom: 0.5rem; }
.cp-card :deep(.cine-clone .table-scroll) { overflow: visible; }

@keyframes fade-up { from { opacity: 0; transform: translateY(14px); } }
@keyframes fade-in { from { opacity: 0; } }

/* Masuk/keluar panggung */
.cine-enter-active { transition: opacity 0.45s ease; }
.cine-leave-active { transition: opacity 0.5s ease 0.35s; }
.cine-enter-from,
.cine-leave-to { opacity: 0; }

/* Footer hanya teks pendukung; di bawah lebar kapsul (± 740px di tengah)
   teks kiri/kanan ikut disembunyikan agar tidak menimpa kapsul */
@media (max-width: 1599px) {
  .cine-skip { display: none; }
}
@media (max-width: 1365px) {
  .cine-date { display: none; }
}
@media (max-width: 900px) {
  .cine-page { display: none; }
  .cine-bar.top { padding-right: calc(4vw + 60px); }
}
@media (max-width: 720px) {
  .cine-stage { padding: 3vh 6vw; }
  .cine-spark { width: 100%; }
  .cine-num { white-space: normal; overflow-wrap: anywhere; }
  .cine-panel { padding: 3vh 4vw 2vh; }
}
@media (prefers-reduced-motion: reduce) {
  .cine-bg { animation: none; }
  .cine *, .cine *::after, .cine *::before { animation-duration: 0.01ms !important; animation-delay: 0s !important; }
  .cine-prog .fill { animation: none !important; transform: none; }
  .cine-spark polyline { stroke-dashoffset: 0; }
  .cine-scene-enter-from, .cine-scene-leave-to { transform: none; filter: none; }
}
</style>
