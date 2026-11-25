<script setup lang="ts">
import { computed, reactive, ref, useId, watch } from 'vue'
import type { PbyCol, PbyFmt } from './PbyTable.vue'
import RpValue from './RpValue.vue'
import { KANTOR_PALETTE } from '../report-helpers'

/* ==========================================================================
   PbyList: pengganti PbyTable utk halaman Pembiayaan. Data & kolom PERSIS
   dari query (props sama dgn PbyTable), ditampilkan ringkas:
   - subtotalBy (kantor): SATU KARTU per kantor; produk di dalamnya 1 baris
     per produk (nama · angka utama), subtotal jadi footer kartu.
   - tanpa subtotalBy (mis. AO / daftar nasabah): kartu-kartu kecil berjejer.
   - "Rincian" per baris = pintasan detail (semua kolom lain), dibuka klik.
   - Kolom & angka tetap dari baris query; tidak ada angka buatan.
   ========================================================================== */

const uid = useId()
const props = withDefaults(
  defineProps<{
    cols: PbyCol[]
    rows: Record<string, unknown>[]
    /** Kolom angka utama tiap baris (default: kolom Rupiah pertama). */
    headKey?: string
    /** Toggle ANGKA PER KARTU (mis. OS pokok / Margin): tiap kartu punya
        pilihan sendiri, default pilihan pertama. Tanpa prop ini -> lama. */
    headChoices?: { key: string; label: string }[]
    subtotalBy?: string
    subtotalLabel?: (row: Record<string, unknown>) => string
    total?: boolean
    totalOverride?: (rows: Record<string, unknown>[]) => Record<string, unknown>
    perPage?: number
    empty?: string
  }>(),
  { perPage: 0, total: true, empty: 'Tidak ada data.' },
)

const isNum = (c: PbyCol): boolean => !!c.fmt && c.fmt !== 'text'
const summable = (c: PbyCol): boolean => c.sum ?? (c.fmt === 'rp' || c.fmt === 'int')

function sumRows(src: Record<string, unknown>[]): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const c of props.cols) {
    if (!summable(c)) continue
    out[c.key] = src.reduce((s, r) => s + (Number(r[c.key]) || 0), 0)
  }
  return { ...out, ...(props.totalOverride?.(src) ?? {}) }
}

function fmt(v: unknown, f: PbyFmt = 'text'): string {
  if (v === null || v === undefined || v === '') return '–'
  if (f === 'text') return String(v)
  const n = Number(v)
  if (Number.isNaN(n)) return String(v)
  if (f === 'pct') return `${n.toLocaleString('id-ID', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`
  return Math.round(n).toLocaleString('id-ID')
}

/* Kolom angka utama, kolom judul (teks pertama) & meta (teks lain). */
const head = computed<PbyCol | undefined>(() =>
  props.cols.find((c) => c.key === props.headKey)
  ?? props.cols.find((c) => c.fmt === 'rp')
  ?? props.cols.find(isNum),
)
/* ---------- Angka per kartu (toggle headChoices) ---------- */
/** Pilihan kolom angka tiap kartu (key kartu -> key kolom). */
const headSel = reactive<Record<string, string>>({})
/** Kolom angka kartu: hasil toggle, atau angka utama global bila tanpa toggle. */
const hcol = (c: Card): PbyCol | undefined => {
  if (!props.headChoices?.length) return head.value
  const k = headSel[c.key] ?? props.headChoices[0].key
  return props.cols.find((x) => x.key === k) ?? head.value
}
const hkey = (c: Card): string => hcol(c)?.key ?? ''
/** Angka (bulat) baris pada kartu c. */
const hnum = (c: Card, d: Record<string, unknown>): number =>
  Math.round(Number(d[hkey(c)]) || 0)
/** Teks angka baris pada kartu c (fmt kolom aktif). */
const htext = (c: Card, d: Record<string, unknown>): string =>
  fmt(d[hkey(c)], hcol(c)?.fmt)
const textCols = computed(() => props.cols.filter((c) => !isNum(c)))
const titleCol = computed<PbyCol | undefined>(() => textCols.value[0])
const metaCols = computed(() => textCols.value.slice(1))
/** Semua kolom selain judul & angka utama -> isi "Rincian". */
const detailCols = computed(() => props.cols.filter((c) => c !== head.value && c !== titleCol.value))
const isRp = (c: PbyCol | undefined): boolean => c?.fmt === 'rp'
/** Kolom rincian dikelompokkan per c.group (mis. tiap kelompok hari tunggakan). */
const detailGroups = computed(() => {
  const out: { name: string; cols: PbyCol[] }[] = []
  for (const c of detailCols.value) {
    const name = c.group ?? ''
    const last = out[out.length - 1]
    if (last && last.name === name) last.cols.push(c)
    else out.push({ name, cols: [c] })
  }
  return out
})

/* ---------- Pager ---------- */
const page = ref(1)
watch(() => props.rows, () => { page.value = 1 })
const pageCount = computed(() =>
  props.perPage > 0 ? Math.max(1, Math.ceil(props.rows.length / props.perPage)) : 1,
)
const visible = computed(() =>
  props.perPage > 0
    ? props.rows.slice((page.value - 1) * props.perPage, page.value * props.perPage)
    : props.rows,
)
const rangeText = computed(() => {
  const n = props.rows.length
  if (!n) return '0 baris'
  const a = (page.value - 1) * props.perPage + 1
  return `${a}–${Math.min(page.value * props.perPage, n)} dari ${n.toLocaleString('id-ID')} baris`
})

/* ---------- Kartu (per kantor) ---------- */
interface Card {
  key: string
  title: string
  sub: string
  rows: Record<string, unknown>[]
  sum: Record<string, unknown>
}

const cards = computed<Card[]>(() => {
  const by = props.subtotalBy
  if (!by) return []
  const out: Card[] = []
  let grp: Record<string, unknown>[] = []
  const flush = (): void => {
    if (!grp.length) return
    const first = grp[0]
    const t = titleCol.value
    out.push({
      key: `c${out.length}`,
      title: props.subtotalLabel
        ? props.subtotalLabel(first).replace(/^Subtotal\s*/i, '')
        : String(t ? first[t.key] ?? '' : ''),
      sub: t?.sub ? String(first[t.sub] ?? '') : '',
      rows: grp,
      sum: sumRows(grp),
    })
    grp = []
  }
  for (const r of visible.value) {
    if (grp.length && grp[0][by] !== r[by]) flush()
    grp.push(r)
  }
  flush()
  return out
})

/* Mode tanpa kantor: setiap baris jadi kartu kecil sendiri (flat). */
const flatRows = computed(() => (props.subtotalBy ? [] : visible.value))
/* Donat porsi tiap produk dalam kantor (angka utama, dari query). Irisan
   berurutan sesuai baris kartu; warna = palet kantor (data encoding). */
interface Slice { key: string; color: string; pct: number; dash: string; off: number; label: string }
function donutOf(c: Card): { slices: Slice[]; total: number } {
  const vals = c.rows.map((r) => Math.max(0, Number(r[hkey(c)]) || 0))
  const total = vals.reduce((a, b) => a + b, 0)
  let acc = 0
  const slices: Slice[] = []
  vals.forEach((v, i) => {
    if (!total || v <= 0) return
    const pct = (v / total) * 100
    slices.push({
      key: `${c.key}-${i}`,
      color: KANTOR_PALETTE[i % KANTOR_PALETTE.length],
      pct,
      dash: `${pct} ${100 - pct}`,
      off: 25 - acc,
      label: `${lineMeta(c.rows[i]) || lineTitle(c.rows[i])}: ${pct.toLocaleString('id-ID', { maximumFractionDigits: 1 })}%`,
    })
    acc += pct
  })
  return { slices, total }
}
/** Porsi produk i dalam kartu kantor (%), dari angka utama query. */
function shareOf(c: Card, i: number): string {
  const k = hkey(c)
  const total = c.rows.reduce((a, r) => a + Math.max(0, Number(r[k]) || 0), 0)
  if (!total) return '–'
  const v = Math.max(0, Number(c.rows[i][k]) || 0)
  return `${((v / total) * 100).toLocaleString('id-ID', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`
}
const donuts = computed(() => new Map(cards.value.map((c) => [c.key, donutOf(c)])))

const totalRow = computed(() => (props.total && props.rows.length ? sumRows(props.rows) : null))

/* ---------- Teks baris ---------- */
const lineTitle = (d: Record<string, unknown>): string => {
  const c = titleCol.value
  return c ? String(d[c.key] ?? '–') : ''
}
const lineSub = (d: Record<string, unknown>): string => {
  const c = titleCol.value
  if (!c?.sub) return ''
  const v = d[c.sub]
  return v == null ? '' : String(v)
}
/** Kolom teks lain (mis. produk) jadi nama baris dlm kartu kantor. */
const lineMeta = (d: Record<string, unknown>): string =>
  metaCols.value
    .map((c) => {
      const v = d[c.key]
      return v === null || v === undefined || v === '' ? '' : String(v)
    })
    .filter(Boolean)
    .join(' · ')
const headOf = (d: Record<string, unknown>): number => Math.round(Number(d[head.value?.key ?? '']) || 0)
/** Kode kolom meta pertama (mis. kdprd di bawah nama produk). */
const prodSub = (d: Record<string, unknown>): string => {
  const k = metaCols.value[0]?.sub
  const v = k ? d[k] : undefined
  return v == null ? '' : String(v)
}
</script>

<template>
  <div class="pl-wrap">
    <div v-if="cards.length || flatRows.length" class="pl-grid">
      <!-- Mode per kantor: satu kartu per kantor, produk 1 baris per produk -->
      <article v-for="c in cards" :key="c.key" class="pl-card">
        <header class="pl-card-head">
          <div class="pl-card-title">
            <svg v-if="donuts.get(c.key)?.slices.length" class="pl-donut" viewBox="0 0 42 42" role="img" :aria-label="`Porsi produk ${c.title}`">
              <!-- Donat 3D: satu cincin digambar ulang sbg lapisan tebal (lebih gelap)
                   lalu cincin atas; keduanya dimiringkan (ellipse) -->
              <defs>
                <g :id="`dn-${uid}-${c.key}`" transform="rotate(-90 21 21)">
                  <circle cx="21" cy="21" r="15.915" fill="none" stroke="var(--surface-3)" stroke-width="6" />
                  <circle
                    v-for="sl in donuts.get(c.key)?.slices" :key="sl.key"
                    cx="21" cy="21" r="15.915" fill="none" stroke-width="6"
                    :stroke="sl.color" :stroke-dasharray="sl.dash" :stroke-dashoffset="sl.off"
                  />
                </g>
              </defs>
              <use
                v-for="k in [3, 2, 1]" :key="k"
                class="pl-depth" :href="`#dn-${uid}-${c.key}`"
                :transform="`translate(21 ${19.4 + k * 1.2}) scale(1 0.62) translate(-21 -21)`"
              />
              <use :href="`#dn-${uid}-${c.key}`" transform="translate(21 19.4) scale(1 0.62) translate(-21 -21)" />
            </svg>
            <div class="pl-card-name">
              {{ c.title }}
              <small v-if="c.sub" class="pl-sub">{{ c.sub }}</small>
              <span v-if="hcol(c)" class="pl-card-sum num">
                <RpValue v-if="isRp(hcol(c))" :value="hnum(c, c.sum)" />
                <template v-else>{{ htext(c, c.sum) }}</template>
              </span>
            </div>
          </div>
        </header>
        <!-- Toggle angka kartu (headChoices): pilih OS pokok / Margin -->
        <div
          v-if="headChoices?.length" class="segmented pl-toggle"
          role="group" aria-label="Angka yang ditampilkan"
        >
          <button
            v-for="hc in headChoices" :key="hc.key" type="button"
            :class="{ on: hkey(c) === hc.key }" @click="headSel[c.key] = hc.key"
          >{{ hc.label }}</button>
        </div>
        <ul class="pl-lines">
          <li v-for="(r, i) in c.rows" :key="i" class="pl-line">
            <details v-if="detailCols.length" class="pl-item">
              <summary class="pl-row">
                <span class="pl-prod">
                  <i class="pl-swatch" :style="{ background: KANTOR_PALETTE[i % KANTOR_PALETTE.length] }" aria-hidden="true" />
                  {{ lineMeta(r) || lineTitle(r) }}
                  <small v-if="prodSub(r)" class="pl-sub">{{ prodSub(r) }}</small>
                </span>
                <span class="pl-val num">
                  <span v-if="hcol(c)"><RpValue v-if="isRp(hcol(c))" :value="hnum(c, r)" bare /><template v-else>{{ htext(c, r) }}</template></span>
                  <small class="pl-pct">{{ shareOf(c, i) }}</small>
                  <svg class="pl-chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
                </span>
              </summary>
              <dl class="pl-kv">
            <div v-for="g in detailGroups" :key="g.name || 'x'" class="kv-group">
              <p v-if="g.name" class="kv-gname">{{ g.name }}</p>
              <div class="kv-items">
                <div v-for="dc in g.cols" :key="dc.key" class="kv-item">
                  <dt>{{ dc.label }}</dt>
                  <dd class="num">
                    <template v-if="dc.fmt === 'rp' && r[dc.key] !== undefined">
                      <RpValue :value="Math.round(Number(r[dc.key]) || 0)" bare />
                    </template>
                    <template v-else>{{ fmt(r[dc.key], dc.fmt) }}</template>
                  </dd>
                </div>
              </div>
            </div>
          </dl>
            </details>
            <div v-else class="pl-row">
              <span class="pl-prod">{{ lineMeta(r) || lineTitle(r) }}</span>
              <span class="pl-val num">
                <span v-if="hcol(c)"><RpValue v-if="isRp(hcol(c))" :value="hnum(c, r)" bare /><template v-else>{{ htext(c, r) }}</template></span>
                <small class="pl-pct">{{ shareOf(c, i) }}</small>
              </span>
            </div>
          </li>
        </ul>
      </article>

      <!-- Mode tanpa kantor (AO / nasabah): kartu kecil berjejer, 1 baris ringkas -->
      <article v-for="(r, i) in flatRows" :key="`f${i}`" class="pl-card flat">
        <details v-if="detailCols.length" class="pl-item">
          <summary class="pl-card-row">
            <span class="pl-prod">
              {{ lineTitle(r) }}
              <small v-if="lineSub(r)" class="pl-sub">{{ lineSub(r) }}</small>
            </span>
            <span class="pl-val num">
              <span v-if="head"><RpValue v-if="isRp(head)" :value="headOf(r)" bare /><template v-else>{{ fmt(r[head.key], head.fmt) }}</template></span>
              <svg class="pl-chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
            </span>
          </summary>
          <dl class="pl-kv">
            <div v-for="g in detailGroups" :key="g.name || 'x'" class="kv-group">
              <p v-if="g.name" class="kv-gname">{{ g.name }}</p>
              <div class="kv-items">
                <div v-for="dc in g.cols" :key="dc.key" class="kv-item">
                  <dt>{{ dc.label }}</dt>
                  <dd class="num">
                    <template v-if="dc.fmt === 'rp' && r[dc.key] !== undefined">
                      <RpValue :value="Math.round(Number(r[dc.key]) || 0)" bare />
                    </template>
                    <template v-else>{{ fmt(r[dc.key], dc.fmt) }}</template>
                  </dd>
                </div>
              </div>
            </div>
          </dl>
        </details>
        <div v-else class="pl-card-row">
          <span class="pl-prod">{{ lineTitle(r) }}</span>
          <span v-if="head" class="pl-val num"><RpValue v-if="isRp(head)" :value="headOf(r)" bare /><template v-else>{{ fmt(r[head.key], head.fmt) }}</template></span>
        </div>
      </article>

      <!-- Total: kartu lebar di bawah -->
      <article v-if="totalRow" class="pl-card total">
        <details v-if="detailCols.length" class="pl-item">
          <summary class="pl-card-row">
            <span class="pl-prod"><b>Total</b></span>
            <span class="pl-val num">
              <span v-if="head"><RpValue v-if="isRp(head)" :value="Math.round(Number(totalRow[head.key]) || 0)" /><template v-else>{{ fmt(totalRow[head.key], head.fmt) }}</template></span>
              <svg class="pl-chev" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
            </span>
          </summary>
          <dl class="pl-kv">
            <div v-for="g in detailGroups" :key="g.name || 'x'" class="kv-group">
              <p v-if="g.name" class="kv-gname">{{ g.name }}</p>
              <div class="kv-items">
                <div v-for="dc in g.cols" :key="dc.key" class="kv-item">
                  <dt>{{ dc.label }}</dt>
                  <dd class="num">
                    <template v-if="dc.fmt === 'rp' && totalRow[dc.key] !== undefined">
                      <RpValue :value="Math.round(Number(totalRow[dc.key]) || 0)" bare />
                    </template>
                    <template v-else>{{ fmt(totalRow[dc.key], dc.fmt) }}</template>
                  </dd>
                </div>
              </div>
            </div>
          </dl>
        </details>
        <div v-else class="pl-card-row">
          <span class="pl-prod"><b>Total</b></span>
          <span v-if="head" class="pl-val num"><RpValue v-if="isRp(head)" :value="Math.round(Number(totalRow[head.key]) || 0)" /><template v-else>{{ fmt(totalRow[head.key], head.fmt) }}</template></span>
        </div>
      </article>
    </div>
    <p v-else class="muted">{{ empty }}</p>

    <div v-if="perPage > 0 && rows.length > perPage" class="pby-pager">
      <button type="button" :disabled="page <= 1" aria-label="Halaman sebelumnya" @click="page--">‹</button>
      <span class="num">Halaman {{ page }} dari {{ pageCount }}, {{ rangeText }}</span>
      <button type="button" :disabled="page >= pageCount" aria-label="Halaman berikutnya" @click="page++">›</button>
    </div>
  </div>
</template>

<style scoped>
/* Kartu padat: 1 kartu = 1 kantor, tiap produk 1 baris (klik = rincian) */
.pl-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 260px), 1fr));
  gap: 0.55rem;
  align-items: start;
}
.pl-card {
  min-width: 0;
  border: 1px solid var(--border-strong);
  border-radius: 10px;
  background: var(--surface);
  padding: 0.45rem 0.55rem;
}
.pl-card.total { grid-column: 1 / -1; background: var(--surface-2); border-color: var(--ink-16); }
/* Toggle angka per kartu (headChoices): lebar penuh, chip kecil */
.pl-toggle { display: flex; width: 100%; margin-top: 0.35rem; padding: 2px; }
.pl-toggle button { flex: 1; min-height: 24px; padding: 0.1rem 0.25rem; font-size: 0.72rem; }
.pl-card-head { display: flex; align-items: center; justify-content: space-between; gap: 0.4rem; min-width: 0; }
.pl-card-name { font-weight: 600; color: var(--ink); font-size: var(--fs-sm); overflow-wrap: anywhere; min-width: 0; }
.pl-card-sum { font-weight: 700; color: var(--ink); white-space: nowrap; font-size: var(--fs-sm); }
.pl-sub { display: inline; margin-left: 0.3rem; font-weight: 400; font-size: 0.75rem; color: var(--muted); }
.pl-meta { margin: 0.2rem 0 0; font-size: var(--fs-sm); color: var(--muted); overflow-wrap: anywhere; }

/* Donat porsi produk: kepala kartu (kiri), kecil */
.pl-card-title { display: flex; align-items: center; gap: 0.45rem; min-width: 0; }
.pl-card-title .pl-card-name { display: flex; flex-direction: column; gap: 0; }
.pl-card-title .pl-card-sum { font-size: 0.8125rem; color: var(--muted-2); font-weight: 600; }
.pl-donut { flex: none; width: 46px; height: 40px; overflow: visible; filter: drop-shadow(0 2px 2px rgba(0, 0, 0, 0.12)); }
.pl-depth { filter: brightness(0.55); }
.pl-swatch { display: inline-block; width: 7px; height: 7px; border-radius: 2px; margin-right: 0.35rem; vertical-align: middle; }

/* Baris produk: satu baris, klik untuk rincian */
.pl-lines { list-style: none; margin: 0.35rem 0 0; padding: 0; display: flex; flex-direction: column; }
.pl-line { border-top: 1px solid var(--border); }
.pl-item > summary, .pl-row {
  display: flex; justify-content: space-between; align-items: center; gap: 0.4rem; min-width: 0;
  padding: 0.22rem 0.1rem; min-height: 28px;
}
.pl-item > summary { cursor: pointer; list-style: none; border-radius: 6px; }
.pl-item > summary::-webkit-details-marker { display: none; }
.pl-item > summary:hover { background: var(--surface-2); }
.pl-item > summary:focus-visible { outline: 2px solid var(--primary-ring); outline-offset: -2px; }
.pl-prod { font-size: 0.8125rem; color: var(--muted-2); min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pl-prod .pl-sub { margin-left: 0.3rem; }
.pl-val { display: inline-flex; align-items: center; gap: 0.35rem; font-size: 0.8125rem; font-weight: 600; color: var(--ink); white-space: nowrap; }
.pl-pct { font-size: 0.75rem; font-weight: 600; color: var(--primary); min-width: 2.8rem; text-align: right; }
.pl-chev { width: 12px; height: 12px; flex: none; fill: none; stroke: var(--muted); stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; transition: transform 0.15s ease; }
.pl-item[open] .pl-chev { transform: rotate(90deg); }

/* Mode AO / daftar: baris ringkas seperti baris produk, rincian 2 kolom */
.pl-card-row {
  display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; min-width: 0;
  padding: 0.2rem 0.1rem; min-height: 30px;
}
.pl-card.flat > .pl-card-row, .pl-card.flat details > summary { padding: 0.2rem 0.1rem; }
.pl-card.flat details > summary { cursor: pointer; list-style: none; border-radius: 6px; display: flex; justify-content: space-between; align-items: center; gap: 0.5rem; min-height: 30px; }
.pl-card.flat details > summary::-webkit-details-marker { display: none; }
.pl-card.flat details > summary:hover { background: var(--surface-2); }
.pl-card.flat details > summary:focus-visible { outline: 2px solid var(--primary-ring); outline-offset: -2px; }
.pl-card.total .pl-prod b { font-weight: 700; color: var(--ink); }
.pl-kv {
  margin: 0.15rem 0 0.35rem; padding: 0.45rem 0.55rem;
  background: var(--surface-2); border-radius: 8px;
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.4rem 0.8rem;
}
.pl-kv { display: flex; flex-direction: column; gap: 0.45rem; }
.kv-gname { margin: 0 0 0.2rem; font-size: 0.72rem; font-weight: 700; color: var(--primary); }
.kv-items { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.25rem 0.8rem; }
.kv-item { min-width: 0; }
.kv-item dt { font-size: 0.72rem; color: var(--muted); line-height: 1.25; overflow-wrap: anywhere; }
.kv-item dd { margin: 0; font-size: 0.8125rem; font-weight: 600; color: var(--ink); white-space: nowrap; }
/* Isi rincian: ringkas, sejajar dgn baris */
.pl-item dl {
  margin: 0 0 0.3rem; padding: 0.4rem 0.5rem;
  background: var(--surface-2); border-radius: 6px;
  display: flex; flex-direction: column; gap: 0.45rem;
}

.pby-pager {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.85rem;
  font-size: var(--fs-sm);
  color: var(--muted);
}
.pby-pager button {
  width: 36px;
  height: 36px;
  border: 1px solid var(--border-strong);
  border-radius: 50%;
  background: var(--surface);
  color: var(--ink);
  font-size: 1.05rem;
  cursor: pointer;
}
.pby-pager button:hover:not(:disabled) { background: var(--surface-2); }
.pby-pager button:disabled { opacity: 0.35; cursor: default; }
</style>
