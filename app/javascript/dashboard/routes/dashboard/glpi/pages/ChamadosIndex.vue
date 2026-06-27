<script setup>
import { ref, computed, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';
import { STATUS_BADGE, PRIO_COLOR, slaBarColor } from '../helpers';
import PeriodFilter from '../components/PeriodFilter.vue';
import TicketDetailModal from '../components/TicketDetailModal.vue';

const tickets = ref([]);
const total = ref(0);
const filterParams = ref({ period: '180d' });
const search = ref('');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const sortKey = ref('id');
const sortDir = ref('desc');
const selectedId = ref(null);

let searchTimer = null;

const COLS = [
  { key: 'id', label: '#' },
  { key: 'cat', label: 'Categoria' },
  { key: 'sol', label: 'Solicitante' },
  { key: 'assignee', label: 'Responsável' },
  { key: 'sector', label: 'Setor' },
  { key: 'statusLabel', label: 'Status' },
  { key: 'prio', label: 'Prioridade' },
  { key: 'sla', label: 'SLA' },
  { key: 'abertoRel', label: 'Aberto' },
];

const sortedTickets = computed(() => {
  const arr = [...tickets.value];
  const k = sortKey.value;
  const dir = sortDir.value === 'asc' ? 1 : -1;
  return arr.sort((a, b) => {
    const va = a[k] ?? '';
    const vb = b[k] ?? '';
    if (typeof va === 'number' && typeof vb === 'number') return (va - vb) * dir;
    return String(va).localeCompare(String(vb), 'pt-BR', { numeric: true }) * dir;
  });
});

function setSort(key) {
  if (sortKey.value === key) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc';
  else {
    sortKey.value = key;
    sortDir.value = 'asc';
  }
}

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getTickets({ ...filterParams.value, search: search.value || undefined });
    tickets.value = data.tickets || [];
    total.value = data.total || tickets.value.length;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function onFilter(params) {
  filterParams.value = params;
  load();
}

function onSearch() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(load, 400);
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Chamados (GLPI)</h1>
      <div class="flex items-center gap-2 flex-wrap">
        <input
          v-model="search"
          type="search"
          placeholder="Buscar por título ou #"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-56"
          @input="onSearch"
        />
        <PeriodFilter @change="onFilter" />
      </div>
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">Configurar agora</router-link>
    </div>

    <p v-else-if="error" class="text-red-500">{{ error }}</p>

    <template v-else>
      <p class="text-sm text-n-slate-11">{{ total }} chamado(s)</p>
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th
              v-for="c in COLS"
              :key="c.key"
              class="py-2 pr-3 cursor-pointer select-none hover:text-n-slate-12"
              @click="setSort(c.key)"
            >
              {{ c.label }}
              <span v-if="sortKey === c.key">{{ sortDir === 'asc' ? '▲' : '▼' }}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in sortedTickets"
            :key="row.id"
            class="border-b border-n-weak/50 hover:bg-n-alpha-black2 cursor-pointer"
            @click="selectedId = row.id"
          >
            <td class="py-2 pr-3 text-n-slate-11">{{ row.id }}</td>
            <td class="py-2 pr-3 text-n-slate-12">{{ row.cat }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sol }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.assignee }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sector }}</td>
            <td class="py-2 pr-3">
              <span class="px-2 py-0.5 rounded-full text-xs" :class="STATUS_BADGE[row.status]">{{ row.statusLabel }}</span>
            </td>
            <td class="py-2 pr-3" :class="PRIO_COLOR[row.prio]">{{ row.prio }}</td>
            <td class="py-2 pr-3">
              <div v-if="row.sla != null" class="w-16 h-1.5 rounded-full bg-n-slate-4">
                <div class="h-1.5 rounded-full" :class="slaBarColor(row.sla)" :style="{ width: row.sla + '%' }" />
              </div>
              <span v-else class="text-n-slate-10">—</span>
            </td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.abertoRel }}</td>
          </tr>
          <tr v-if="!sortedTickets.length">
            <td :colspan="COLS.length" class="py-6 text-center text-n-slate-11">Nenhum chamado no período.</td>
          </tr>
        </tbody>
      </table>
    </template>

    <TicketDetailModal v-if="selectedId" :ticket-id="selectedId" @close="selectedId = null" />
  </div>
</template>
