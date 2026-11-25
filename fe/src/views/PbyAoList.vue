<script setup lang="ts">
import { computed } from 'vue'
import RpValue from './RpValue.vue'
import { pctText, type Row } from '../pby-helpers'

/* Tampilan per AO: kartu berperingkat (nilai terbesar dulu) dengan avatar
   inisial, porsi thd total (bar), dan rincian kecil per AO. */
export interface AoDetail { label: string; text: (r: Row) => string; bad?: (r: Row) => boolean }

const props = defineProps<{
  rows: Row[]
  /** Nilai utama tiap AO (urutan & bar porsi). */
  value: (r: Row) => number
  valueLabel: string
  details: AoDetail[]
  colors: Map<string, string>
  /** Teks tambahan di baris total (mis. NPF % keseluruhan). */
  totalNote?: string
  empty?: string
}>()

const total = computed(() => props.rows.reduce((t, r) => t + props.value(r), 0))
const list = computed(() => {
  const max = Math.max(1, ...props.rows.map((r) => props.value(r)))
  return [...props.rows]
    .map((r) => ({ r, v: props.value(r) }))
    .sort((a, b) => b.v - a.v)
    .map(({ r, v }, i) => ({
      r, v, rank: i + 1,
      id: String(r.kdaoh ?? ''),
      name: String(r.nmao || 'Tanpa AO'),
      bar: (v / max) * 100,
      share: total.value ? (v / total.value) * 100 : null,
    }))
})
const initials = (name: string): string =>
  name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase() || '–'
const colorOf = (id: string): string => props.colors.get(id) ?? 'var(--primary)'
</script>

<template>
  <p v-if="!rows.length" class="muted">{{ empty ?? 'Tidak ada data AO.' }}</p>
  <div v-else>
    <ol class="ao-grid">
      <li v-for="a in list" :key="a.id" class="ao-card">
        <div class="ao-top">
          <span class="ao-rank num">{{ a.rank }}</span>
          <span class="ao-avatar" :style="{ background: colorOf(a.id) }" aria-hidden="true">{{ initials(a.name) }}</span>
          <div class="ao-id">
            <strong>{{ a.name }}</strong>
            <small>{{ a.id }}</small>
          </div>
        </div>
        <div class="ao-val">
          <span class="num"><RpValue :value="Math.round(a.v)" /></span>
          <small>{{ valueLabel }} · {{ a.share == null ? '–' : pctText(a.share) }} dari total</small>
        </div>
        <div class="ao-bar" role="presentation"><i :style="{ width: `${a.bar}%`, background: colorOf(a.id) }" /></div>
        <dl class="ao-meta">
          <div v-for="d in details" :key="d.label">
            <dt>{{ d.label }}</dt>
            <dd class="num" :class="{ bad: d.bad?.(a.r) }">{{ d.text(a.r) }}</dd>
          </div>
        </dl>
      </li>
    </ol>
    <div class="ao-total">
      <span>Total <small>{{ rows.length }} AO{{ totalNote ? ` · ${totalNote}` : '' }}</small></span>
      <strong class="num"><RpValue :value="Math.round(total)" /></strong>
    </div>
  </div>
</template>

<style scoped>
.ao-grid {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 0.75rem; margin: 0; padding: 0; list-style: none;
}
.ao-card {
  display: flex; flex-direction: column; gap: 0.7rem;
  padding: 0.9rem 1rem; border: 1px solid var(--border-strong);
  border-radius: var(--radius-md, 10px); background: var(--surface);
}
.ao-top { display: flex; align-items: center; gap: 0.7rem; min-width: 0; }
.ao-rank { flex: none; width: 1.25rem; font-size: var(--fs-sm); font-weight: 600; color: var(--muted); text-align: center; }
.ao-avatar {
  flex: none; display: grid; place-items: center;
  width: 36px; height: 36px; border-radius: 50%;
  color: #fff; font-size: var(--fs-sm); font-weight: 600; letter-spacing: 0.02em;
}
.ao-id { display: flex; flex-direction: column; min-width: 0; flex: 1 1 auto; }
.ao-id strong { font-size: var(--fs-base); font-weight: 600; color: var(--ink); line-height: 1.3; overflow-wrap: anywhere; }
.ao-id small, .ao-val small { font-size: var(--fs-sm); color: var(--muted); }
.ao-val { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 0.25rem 0.75rem; }
.ao-val .num { font-size: var(--fs-lg); font-weight: 600; color: var(--ink); white-space: nowrap; }
.ao-bar { height: 6px; border-radius: 999px; background: var(--ink-10, rgba(0, 0, 0, 0.06)); overflow: hidden; }
.ao-bar i { display: block; height: 100%; border-radius: inherit; }
.ao-meta {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(90px, 1fr));
  gap: 0.5rem 1rem; margin: 0; padding-top: 0.6rem; border-top: 1px dashed var(--border-strong);
}
.ao-meta dt { font-size: var(--fs-sm); color: var(--muted); }
.ao-meta dd { margin: 0.1rem 0 0; font-size: var(--fs-sm); font-weight: 600; color: var(--ink); }
.ao-meta dd.bad { color: var(--red-dark); }
.ao-total {
  display: flex; justify-content: space-between; align-items: center; gap: 1rem;
  margin-top: 0.75rem; padding: 0.8rem 1rem;
  border: 1px solid var(--border-strong); border-radius: var(--radius-md, 10px);
  background: var(--surface-2, rgba(0, 0, 0, 0.03));
  font-size: var(--fs-sm); font-weight: 600; color: var(--ink);
}
.ao-total small { margin-left: 0.4rem; font-weight: 400; color: var(--muted); }
.ao-total strong { font-size: var(--fs-base); }
</style>
