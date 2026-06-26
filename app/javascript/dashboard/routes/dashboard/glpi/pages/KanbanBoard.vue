<script setup>
import { ref, computed, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const COLUMNS = [
  { key: 'aberto', label: 'Aberto' },
  { key: 'aguardando_aprovacao', label: 'Aguardando aprovação' },
  { key: 'em_execucao', label: 'Em execução' },
  { key: 'resolvido', label: 'Resolvido' },
  { key: 'violou_sla', label: 'Violou SLA' },
];

const tickets = ref([]);
const period = ref('180d');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const grouped = computed(() => {
  const map = Object.fromEntries(COLUMNS.map(c => [c.key, []]));
  tickets.value.forEach(t => {
    (map[t.status] ||= []).push(t);
  });
  return map;
});

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getTickets({ period: period.value });
    tickets.value = data.tickets || [];
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">Kanban (GLPI)</h1>
      <select
        v-model="period"
        class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1 text-n-slate-12"
        @change="load"
      >
        <option value="7d">Últimos 7 dias</option>
        <option value="30d">Últimos 30 dias</option>
        <option value="90d">Últimos 90 dias</option>
        <option value="180d">Últimos 180 dias</option>
      </select>
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">
        Configurar agora
      </router-link>
    </div>

    <p v-else-if="error" class="text-red-500">{{ error }}</p>

    <div v-else class="flex gap-4 overflow-x-auto h-full pb-2">
      <div
        v-for="col in COLUMNS"
        :key="col.key"
        class="flex flex-col w-72 shrink-0 rounded-xl bg-n-alpha-black2 p-3 gap-2"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-12">{{ col.label }}</span>
          <span class="text-xs text-n-slate-11">{{ grouped[col.key].length }}</span>
        </div>
        <div class="flex flex-col gap-2 overflow-y-auto">
          <div
            v-for="card in grouped[col.key]"
            :key="card.id"
            class="rounded-lg bg-n-solid-2 border border-n-weak p-3"
          >
            <p class="text-xs text-n-slate-11">#{{ card.id }} · {{ card.prio }}</p>
            <p class="text-sm text-n-slate-12">{{ card.cat }}</p>
            <p class="text-xs text-n-slate-11 mt-1">{{ card.sol }} · {{ card.sector }}</p>
          </div>
          <p v-if="!grouped[col.key].length" class="text-xs text-n-slate-10 py-2">—</p>
        </div>
      </div>
    </div>
  </div>
</template>
