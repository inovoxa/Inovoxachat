<script setup>
import { ref, computed, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';
import { STATUS_BADGE, PRIO_COLOR, slaBarColor, PERIOD_OPTIONS } from '../helpers';

const tickets = ref([]);
const total = ref(0);
const period = ref('180d');
const search = ref('');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const sortKey = ref('id');
const sortDir = ref('desc');

const detail = ref(null);
const detailLoading = ref(false);
const detailError = ref('');
const showModal = ref(false);

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
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortKey.value = key;
    sortDir.value = 'asc';
  }
}

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getTickets({ period: period.value, search: search.value || undefined });
    tickets.value = data.tickets || [];
    total.value = data.total || tickets.value.length;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function onSearch() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(load, 400);
}

async function openDetail(id) {
  showModal.value = true;
  detail.value = null;
  detailError.value = '';
  detailLoading.value = true;
  try {
    const { data } = await GlpiAPI.getTicket(id);
    detail.value = data;
  } catch (e) {
    detailError.value = e.response?.data?.error || e.message;
  } finally {
    detailLoading.value = false;
  }
}

function closeModal() {
  showModal.value = false;
  detail.value = null;
}

const TL_LABEL = {
  abertura: 'Abertura', followup: 'Acompanhamento', tarefa: 'Tarefa',
  solucao: 'Solução', resolvido: 'Resolvido', fechado: 'Fechado',
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Chamados (GLPI)</h1>
      <div class="flex items-center gap-2">
        <input
          v-model="search"
          type="search"
          placeholder="Buscar por título ou #"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-56"
          @input="onSearch"
        />
        <select
          v-model="period"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
          @change="load"
        >
          <option v-for="o in PERIOD_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
        </select>
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
            @click="openDetail(row.id)"
          >
            <td class="py-2 pr-3 text-n-slate-11">{{ row.id }}</td>
            <td class="py-2 pr-3 text-n-slate-12">{{ row.cat }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sol }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.assignee }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sector }}</td>
            <td class="py-2 pr-3">
              <span class="px-2 py-0.5 rounded-full text-xs" :class="STATUS_BADGE[row.status]">
                {{ row.statusLabel }}
              </span>
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

    <!-- Modal de detalhe -->
    <div
      v-if="showModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      @click.self="closeModal"
    >
      <div class="bg-n-solid-1 rounded-2xl w-full max-w-2xl max-h-[85vh] overflow-auto p-6 flex flex-col gap-4 border border-n-weak">
        <div class="flex items-start justify-between">
          <h2 class="text-lg font-medium text-n-slate-12">
            Chamado <span v-if="detail">#{{ detail.ticket.id }}</span>
          </h2>
          <button class="text-n-slate-11 hover:text-n-slate-12" @click="closeModal">✕</button>
        </div>

        <p v-if="detailLoading" class="text-n-slate-11">Carregando…</p>
        <p v-else-if="detailError" class="text-red-500 text-sm">{{ detailError }}</p>

        <template v-else-if="detail">
          <div>
            <p class="text-base text-n-slate-12">{{ detail.ticket.titulo }}</p>
            <p class="text-xs text-n-slate-11 mt-1 flex items-center gap-2 flex-wrap">
              <span class="px-2 py-0.5 rounded-full" :class="STATUS_BADGE[detail.ticket.status]">{{ detail.ticket.statusLabel }}</span>
              <span :class="PRIO_COLOR[detail.ticket.prio]">{{ detail.ticket.prio }}</span>
              <span>{{ detail.ticket.cat }}</span>
              <span>aberto em {{ detail.ticket.abertoFull }}</span>
            </p>
          </div>

          <div class="grid grid-cols-2 gap-2 text-sm">
            <p><span class="text-n-slate-11">Solicitante:</span> {{ detail.ticket.sol }}</p>
            <p><span class="text-n-slate-11">Responsável:</span> {{ detail.ticket.assignee }}</p>
            <p><span class="text-n-slate-11">Setor:</span> {{ detail.ticket.sector }}</p>
            <p><span class="text-n-slate-11">Canal:</span> {{ detail.ticket.canal }}</p>
            <p><span class="text-n-slate-11">Urgência:</span> {{ detail.ticket.urgencia }}</p>
            <p><span class="text-n-slate-11">Impacto:</span> {{ detail.ticket.impacto }}</p>
            <p><span class="text-n-slate-11">Entidade:</span> {{ detail.ticket.entidade }}</p>
            <p><span class="text-n-slate-11">Local:</span> {{ detail.ticket.local }}</p>
          </div>

          <div>
            <p class="text-sm font-medium text-n-slate-12 mb-1">Descrição</p>
            <p class="text-sm text-n-slate-11 whitespace-pre-line">{{ detail.ticket.descricao }}</p>
          </div>

          <div v-if="detail.anexos.length">
            <p class="text-sm font-medium text-n-slate-12 mb-1">Anexos</p>
            <ul class="text-sm text-n-slate-11 list-disc list-inside">
              <li v-for="a in detail.anexos" :key="a.arquivo">{{ a.nome }}</li>
            </ul>
          </div>

          <div>
            <p class="text-sm font-medium text-n-slate-12 mb-2">Linha do tempo</p>
            <div class="flex flex-col gap-3">
              <div v-for="(ev, i) in detail.timeline" :key="i" class="border-l-2 border-n-weak pl-3">
                <p class="text-xs text-n-slate-11">
                  {{ TL_LABEL[ev.tipo] || ev.tipo }}<span v-if="ev.autor"> · {{ ev.autor }}</span>
                </p>
                <p class="text-sm text-n-slate-12 whitespace-pre-line">{{ ev.texto }}</p>
              </div>
              <p v-if="!detail.timeline.length" class="text-sm text-n-slate-11">Sem eventos.</p>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
