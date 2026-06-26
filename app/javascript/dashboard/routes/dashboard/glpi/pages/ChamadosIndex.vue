<script setup>
import { ref, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const tickets = ref([]);
const total = ref(0);
const period = ref('180d');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const detail = ref(null);
const detailLoading = ref(false);
const detailError = ref('');
const showModal = ref(false);

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getTickets({ period: period.value });
    tickets.value = data.tickets || [];
    total.value = data.total || tickets.value.length;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
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
  abertura: 'Abertura',
  followup: 'Acompanhamento',
  tarefa: 'Tarefa',
  solucao: 'Solução',
  resolvido: 'Resolvido',
  fechado: 'Fechado',
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">Chamados (GLPI)</h1>
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

    <template v-else>
      <p class="text-sm text-n-slate-11">{{ total }} chamado(s)</p>
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-n-slate-11 border-b border-n-weak">
            <th class="py-2 pr-3">#</th>
            <th class="py-2 pr-3">Categoria</th>
            <th class="py-2 pr-3">Solicitante</th>
            <th class="py-2 pr-3">Setor</th>
            <th class="py-2 pr-3">Status</th>
            <th class="py-2 pr-3">Prioridade</th>
            <th class="py-2 pr-3">Aberto</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in tickets"
            :key="row.id"
            class="border-b border-n-weak/50 hover:bg-n-alpha-black2 cursor-pointer"
            @click="openDetail(row.id)"
          >
            <td class="py-2 pr-3 text-n-slate-11">{{ row.id }}</td>
            <td class="py-2 pr-3 text-n-slate-12">{{ row.cat }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sol }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.sector }}</td>
            <td class="py-2 pr-3 text-n-slate-12">{{ row.statusLabel }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.prio }}</td>
            <td class="py-2 pr-3 text-n-slate-11">{{ row.abertoRel }}</td>
          </tr>
          <tr v-if="!tickets.length">
            <td colspan="7" class="py-6 text-center text-n-slate-11">Nenhum chamado no período.</td>
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
            <p class="text-xs text-n-slate-11 mt-1">
              {{ detail.ticket.cat }} · {{ detail.ticket.statusLabel }} · {{ detail.ticket.prio }} ·
              aberto em {{ detail.ticket.abertoFull }}
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
                  {{ TL_LABEL[ev.tipo] || ev.tipo }}
                  <span v-if="ev.autor"> · {{ ev.autor }}</span>
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
