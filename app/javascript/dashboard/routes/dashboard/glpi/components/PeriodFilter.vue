<script setup>
import { ref } from 'vue';
import { PERIOD_OPTIONS } from '../helpers';

const emit = defineEmits(['change']);

const mode = ref('180d'); // preset ('7d'...) ou 'custom'
const from = ref('');
const to = ref('');

function onSelect() {
  if (mode.value !== 'custom') emit('change', { period: mode.value });
}

function applyCustom() {
  if (from.value && to.value) emit('change', { from: from.value, to: to.value });
}
</script>

<template>
  <div class="flex items-center gap-2 flex-wrap">
    <select
      v-model="mode"
      class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
      @change="onSelect"
    >
      <option v-for="o in PERIOD_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
      <option value="custom">Intervalo personalizado…</option>
    </select>

    <template v-if="mode === 'custom'">
      <input
        v-model="from"
        type="date"
        class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
      />
      <span class="text-sm text-n-slate-11">até</span>
      <input
        v-model="to"
        type="date"
        class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
      />
      <button
        type="button"
        class="text-sm rounded-lg bg-woot-500 px-3 py-1.5 text-white disabled:opacity-60"
        :disabled="!from || !to"
        @click="applyCustom"
      >
        Aplicar
      </button>
    </template>
  </div>
</template>
