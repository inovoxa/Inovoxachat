<script setup>
import { reactive, ref, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import GlpiAPI from 'dashboard/api/glpi';
import { PRIO_COLOR, slaBarColor, KANBAN_COLOR } from '../helpers';
import PeriodFilter from '../components/PeriodFilter.vue';
import TicketDetailModal from '../components/TicketDetailModal.vue';

const COLUMNS = [
  { key: 'aberto', label: 'Aberto' },
  { key: 'aguardando_aprovacao', label: 'Aguardando aprovação' },
  { key: 'em_execucao', label: 'Em execução' },
  { key: 'resolvido', label: 'Resolvido' },
  { key: 'violou_sla', label: 'Violou SLA' },
];
const GRAVAVEL = ['aberto', 'aguardando_aprovacao', 'em_execucao', 'resolvido'];

const columns = reactive({});
COLUMNS.forEach(c => {
  columns[c.key] = [];
});
const filterParams = ref({ period: '180d' });
const search = ref('');
const loading = ref(true);
const saving = ref(false);
const notConfigured = ref(false);
const error = ref('');
const selectedId = ref(null);
let searchTimer = null;

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getTickets({ ...filterParams.value, search: search.value || undefined });
    COLUMNS.forEach(c => {
      columns[c.key] = [];
    });
    (data.tickets || []).forEach(t => {
      (columns[t.status] || columns.aberto).push(t);
    });
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

async function onChange(colKey, evt) {
  if (!evt.added) return;
  const card = evt.added.element;
  if (!GRAVAVEL.includes(colKey)) {
    error.value = 'A coluna "Violou SLA" é derivada e não pode receber cards.';
    await load();
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    await GlpiAPI.updateTicketStatus(card.id, colKey);
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
    await load();
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">
        Kanban (GLPI)
        <span v-if="saving" class="text-xs text-n-slate-11">· salvando…</span>
      </h1>
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

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">Configurar agora</router-link>
    </div>

    <div v-else class="flex gap-4 overflow-x-auto h-full pb-2">
      <div
        v-for="col in COLUMNS"
        :key="col.key"
        class="flex flex-col w-72 shrink-0 rounded-xl bg-n-alpha-black2 p-3 gap-2 border-t-4"
        :style="{ borderTopColor: KANBAN_COLOR[col.key] }"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold flex items-center gap-2" :style="{ color: KANBAN_COLOR[col.key] }">
            <span class="w-2 h-2 rounded-full" :style="{ backgroundColor: KANBAN_COLOR[col.key] }" />
            {{ col.label }}
          </span>
          <span
            class="text-xs px-1.5 rounded-full"
            :style="{ color: KANBAN_COLOR[col.key], backgroundColor: KANBAN_COLOR[col.key] + '22' }"
          >
            {{ columns[col.key].length }}
          </span>
        </div>
        <Draggable
          v-model="columns[col.key]"
          group="kanban"
          item-key="id"
          class="flex flex-col gap-2 flex-1 min-h-8 overflow-y-auto"
          @change="e => onChange(col.key, e)"
        >
          <template #item="{ element }">
            <div
              class="rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-grab flex flex-col gap-1 hover:border-n-slate-7"
              @click="selectedId = element.id"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs text-n-slate-11">#{{ element.id }}</span>
                <span class="text-xs font-medium" :class="PRIO_COLOR[element.prio]">{{ element.prio }}</span>
              </div>
              <p class="text-sm text-n-slate-12">{{ element.cat }}</p>
              <p class="text-xs text-n-slate-11">{{ element.sol }} · {{ element.sector }}</p>
              <div v-if="element.sla != null" class="w-full h-1 rounded-full bg-n-slate-4 mt-1">
                <div class="h-1 rounded-full" :class="slaBarColor(element.sla)" :style="{ width: element.sla + '%' }" />
              </div>
            </div>
          </template>
        </Draggable>
      </div>
    </div>

    <TicketDetailModal v-if="selectedId" :ticket-id="selectedId" @close="selectedId = null" />
  </div>
</template>
