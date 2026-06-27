<script setup>
import { ref, watch } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';
import { STATUS_BADGE, PRIO_COLOR } from '../helpers';

const props = defineProps({
  ticketId: { type: [Number, String], default: null },
});
const emit = defineEmits(['close']);

const detail = ref(null);
const loading = ref(false);
const error = ref('');

const TL_LABEL = {
  abertura: 'Abertura', followup: 'Acompanhamento', tarefa: 'Tarefa',
  solucao: 'Solução', resolvido: 'Resolvido', fechado: 'Fechado',
};

watch(
  () => props.ticketId,
  async id => {
    if (!id) {
      detail.value = null;
      return;
    }
    detail.value = null;
    error.value = '';
    loading.value = true;
    try {
      const { data } = await GlpiAPI.getTicket(id);
      detail.value = data;
    } catch (e) {
      error.value = e.response?.data?.error || e.message;
    } finally {
      loading.value = false;
    }
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div class="bg-n-solid-1 rounded-2xl w-full max-w-2xl max-h-[85vh] overflow-auto p-6 flex flex-col gap-4 border border-n-weak">
      <div class="flex items-start justify-between">
        <h2 class="text-lg font-medium text-n-slate-12">
          Chamado <span v-if="detail">#{{ detail.ticket.id }}</span>
        </h2>
        <button class="text-n-slate-11 hover:text-n-slate-12" @click="emit('close')">✕</button>
      </div>

      <p v-if="loading" class="text-n-slate-11">Carregando…</p>
      <p v-else-if="error" class="text-red-500 text-sm">{{ error }}</p>

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
</template>
