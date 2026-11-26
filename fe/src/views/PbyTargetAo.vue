<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import RpValue from './RpValue.vue'

/* ==========================================================================
   PbyTargetAo: kartu per AO dari 003 Pembiayaan Target AO.sql.
   Tiap kartu: Pembiayaan (loan / rloan / bdr_loan), Deposito (dep / rdep /
   bdr_dep), Tabungan (tab; rtab di query selalu 0 -> hanya target).
   Bar = capaian % (bdr_*) dari query, dibatasi 100% secara visual.
   Maks 8 kartu per halaman (2 baris x 4).
   ========================================================================== */

type Row = Record<string, unknown>
const props = withDefaults(
  defineProps<{ rows: Row[]; kantorNama?: Map<string, string>; perPage?: number }>(),
  { perPage: 8 },
)

const n = (v: unknown): number => Number(v) || 0
const str = (v: unknown): string => (v == null ? '' : String(v).trim())
const pct = (v: number): string =>
  `${v.toLocaleString('id-ID', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`
/** Capaian: >= 100 tercapai, 50–99 sedang, < 50 rendah. */
const tone = (v: number): string => (v >= 100 ? 'ok' : v >= 50 ? 'mid' : 'low')
const initials = (name: string): string =>
  name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase() || '–'

interface Metric { label: string; target: number; real: number; bdr: number }
const metrics = (r: Row): Metric[] => [
  { label: 'Pembiayaan', target: n(r.loan), real: n(r.rloan), bdr: n(r.bdr_loan) },
  { label: 'Deposito', target: n(r.dep), real: n(r.rdep), bdr: n(r.bdr_dep) },
]

const page = ref(1)
watch(() => props.rows, () => { page.value = 1 })
const pageCount = computed(() => Math.max(1, Math.ceil(props.rows.length / props.perPage)))
const visible = computed(() => props.rows.slice((page.value - 1) * props.perPage, page.value * props.perPage))
const rangeText = computed(() => {
  const t = props.rows.length
  const a = (page.value - 1) * props.perPage + 1
  return `${a}–${Math.min(page.value * props.perPage, t)} dari ${t} AO`
})
</script>

<template>
  <div class="ta">
    <ul class="ta-grid">
      <li v-for="r in visible" :key="str(r.kdao)" class="ta-card">
        <header class="ta-head">
          <span class="ta-av" aria-hidden="true">{{ initials(str(r.nmao)) }}</span>
          <div class="ta-who">
            <b>{{ str(r.nmao) || 'Tanpa nama' }}</b>
            <small>
              <span class="num">{{ str(r.kdao) }}</span> ·
              {{ kantorNama?.get(str(r.kdloc)) ?? `Kantor ${str(r.kdloc)}` }}
            </small>
          </div>
        </header>

        <div v-for="m in metrics(r)" :key="m.label" class="ta-m">
          <div class="ta-m-top">
            <span class="ta-m-lbl">{{ m.label }}</span>
            <span class="ta-m-pct num" :class="tone(m.bdr)">{{ m.target ? pct(m.bdr) : '–' }}</span>
          </div>
          <div
            class="ta-bar" role="progressbar" :aria-label="`Capaian ${m.label}`"
            aria-valuemin="0" aria-valuemax="100" :aria-valuenow="Math.round(Math.min(100, m.bdr))"
          >
            <i :class="tone(m.bdr)" :style="{ width: `${Math.min(100, Math.max(0, m.bdr))}%` }" />
          </div>
          <div class="ta-m-nums num">
            <span><RpValue :value="Math.round(m.real)" /></span>
            <span class="ta-m-of">dari <RpValue :value="Math.round(m.target)" /></span>
          </div>
        </div>

        <div class="ta-m ta-tab">
          <div class="ta-m-top">
            <span class="ta-m-lbl">Tabungan</span>
            <span class="ta-m-of num">Target <RpValue :value="Math.round(n(r.tab))" /></span>
          </div>
          <small class="ta-note">Realisasi belum tersedia di query</small>
        </div>
      </li>
    </ul>

    <nav v-if="pageCount > 1" class="pby-pager ta-pager" aria-label="Halaman target AO">
      <button type="button" class="ta-step" :disabled="page <= 1" aria-label="Halaman sebelumnya" @click="page--">‹</button>
      <button
        v-for="p in pageCount" :key="p" type="button" class="ta-num num" :class="{ on: p === page }"
        :aria-current="p === page ? 'page' : undefined" :aria-label="`Halaman ${p}`" @click="page = p"
      >{{ p }}</button>
      <button type="button" class="ta-step" :disabled="page >= pageCount" aria-label="Halaman berikutnya" @click="page++">›</button>
      <span class="ta-range num">{{ rangeText }}</span>
    </nav>
  </div>
</template>

<style scoped>
.ta-grid {
  list-style: none; margin: 0; padding: 0;
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 0.65rem;
}
@media (max-width: 1280px) { .ta-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 980px) { .ta-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 620px) { .ta-grid { grid-template-columns: minmax(0, 1fr); } }

.ta-card {
  display: flex; flex-direction: column; gap: 0.7rem; min-width: 0;
  border: 1px solid var(--border-strong); border-radius: 12px;
  background: var(--surface); padding: 0.8rem 0.85rem;
}
.ta-head { display: flex; align-items: center; gap: 0.6rem; min-width: 0; }
.ta-av {
  flex: none; width: 34px; height: 34px; border-radius: 50%;
  display: grid; place-items: center;
  background: color-mix(in srgb, var(--primary) 14%, transparent); color: var(--primary);
  font-size: 0.75rem; font-weight: 700;
}
.ta-who { display: flex; flex-direction: column; min-width: 0; }
.ta-who b { font-size: var(--fs-sm); font-weight: 600; color: var(--ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ta-who small { font-size: 0.75rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.ta-m { padding-top: 0.6rem; border-top: 1px solid var(--border); }
.ta-m-top { display: flex; justify-content: space-between; align-items: baseline; gap: 0.5rem; }
.ta-m-lbl { font-size: 0.8125rem; font-weight: 600; color: var(--ink); }
.ta-m-pct { font-size: 0.8125rem; font-weight: 700; }
.ta-m-pct.ok { color: var(--green-dark); }
.ta-m-pct.mid { color: var(--amber); }
.ta-m-pct.low { color: var(--red-dark); }
.ta-bar { height: 6px; margin: 0.35rem 0; border-radius: 999px; background: var(--surface-2); overflow: hidden; }
.ta-bar i { display: block; height: 100%; border-radius: inherit; transition: width 0.4s ease; }
.ta-bar i.ok { background: var(--green); }
.ta-bar i.mid { background: var(--amber); }
.ta-bar i.low { background: var(--red); }
.ta-m-nums { display: flex; justify-content: space-between; align-items: baseline; gap: 0.5rem; font-size: 0.8125rem; font-weight: 600; color: var(--ink); white-space: nowrap; }
.ta-m-of { font-size: 0.75rem; font-weight: 400; color: var(--muted); white-space: nowrap; }
.ta-tab { margin-top: auto; }
.ta-note { display: block; margin-top: 0.15rem; font-size: 0.7rem; color: var(--muted); font-style: italic; }

.ta-pager { display: flex; flex-wrap: wrap; align-items: center; gap: 0.3rem; margin-top: 0.9rem; }
.ta-pager .ta-num,
.ta-pager .ta-step {
  min-width: 34px; height: 34px; padding: 0 0.5rem;
  border: 1px solid var(--border-strong); border-radius: 8px;
  background: var(--surface); color: var(--ink); font: inherit; font-size: var(--fs-sm); cursor: pointer;
}
.ta-pager .ta-num:hover:not(.on),
.ta-pager .ta-step:hover:not(:disabled) { background: var(--surface-2); }
.ta-pager .ta-num.on { background: var(--primary); border-color: var(--primary); color: var(--on-primary, #fff); font-weight: 600; }
.ta-pager .ta-step:disabled { opacity: 0.35; cursor: default; }
.ta-range { margin-left: auto; font-size: var(--fs-sm); color: var(--muted); }
@media (prefers-reduced-motion: reduce) { .ta-bar i { transition: none; } }
</style>
