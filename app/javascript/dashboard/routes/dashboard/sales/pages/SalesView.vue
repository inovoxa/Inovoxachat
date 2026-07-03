<script setup>
import { ref, computed, onMounted } from 'vue';
import QuotationsAPI from 'dashboard/api/quotations';
import { useAlert } from 'dashboard/composables';
import QuotationDialog from '../components/QuotationDialog.vue';

const FILTROS = [
  { key: '', label: 'Todas' },
  { key: 'cotacao', label: 'Cotações' },
  { key: 'enviada', label: 'Enviadas' },
  { key: 'pedido', label: 'Pedidos' },
  { key: 'cancelada', label: 'Canceladas' },
];
const STATUS_LABEL = {
  cotacao: 'Cotação',
  enviada: 'Enviada',
  pedido: 'Pedido',
  cancelada: 'Cancelada',
};
const STATUS_CLASS = {
  cotacao: 'bg-n-slate-4 text-n-slate-11',
  enviada: 'bg-blue-500/15 text-blue-600',
  pedido: 'bg-teal-500/15 text-teal-600',
  cancelada: 'bg-red-500/15 text-red-600',
};

const quotations = ref([]);
const filtro = ref('');
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const dialogRef = ref(null);

function fmtValor(v) {
  return Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
function fmtData(d) {
  return d ? new Date(d).toLocaleDateString('pt-BR') : '—';
}

const totalPedidos = computed(() =>
  quotations.value.filter(q => q.status === 'pedido').reduce((s, q) => s + Number(q.amount_total || 0), 0)
);

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await QuotationsAPI.get(filtro.value ? { status: filtro.value } : {});
    quotations.value = data.payload || [];
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function setFiltro(k) {
  filtro.value = k;
  load();
}

function novo() {
  dialogRef.value?.open({});
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await QuotationsAPI.update(payload.id, { quotation: payload });
    else await QuotationsAPI.create({ quotation: payload });
    dialogRef.value?.onSuccess();
    useAlert('Cotação salva.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar a cotação.');
  } finally {
    saving.value = false;
  }
}

async function acao(fn, okMsg, { id }) {
  saving.value = true;
  try {
    await fn(id);
    dialogRef.value?.onSuccess();
    useAlert(okMsg);
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Não foi possível concluir a ação.');
  } finally {
    saving.value = false;
  }
}
const enviar = p => acao(id => QuotationsAPI.sendQuote(id), 'Cotação enviada.', p);
const confirmar = p => acao(id => QuotationsAPI.confirm(id), 'Pedido confirmado — contrato gerado.', p);
const cancelar = p => acao(id => QuotationsAPI.cancel(id), 'Cotação cancelada.', p);

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">Vendas · Cotações</h1>
        <p class="text-sm text-n-slate-11">Pedidos confirmados: {{ fmtValor(totalPedidos) }}</p>
      </div>
      <button
        class="rounded-lg bg-woot-500 px-4 py-1.5 text-sm font-medium text-white hover:bg-woot-600"
        @click="novo"
      >
        + Nova cotação
      </button>
    </div>

    <div class="flex items-center gap-1 flex-wrap">
      <button
        v-for="f in FILTROS"
        :key="f.key"
        class="text-xs px-3 py-1.5 rounded-lg"
        :class="filtro === f.key ? 'bg-woot-500 text-white' : 'bg-n-alpha-black2 text-n-slate-11 hover:text-n-slate-12'"
        @click="setFiltro(f.key)"
      >
        {{ f.label }}
      </button>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="!quotations.length" class="text-n-slate-11 text-sm">
      Nenhuma cotação. Clique em “Nova cotação” para começar.
    </div>

    <div v-else class="flex-1 overflow-auto rounded-xl border border-n-weak">
      <table class="w-full text-sm">
        <thead class="bg-n-alpha-black2 text-n-slate-11 text-xs">
          <tr>
            <th class="text-left font-medium px-4 py-2">Número</th>
            <th class="text-left font-medium px-4 py-2">Cliente</th>
            <th class="text-left font-medium px-4 py-2">Vendedor</th>
            <th class="text-left font-medium px-4 py-2">Expiração</th>
            <th class="text-left font-medium px-4 py-2">Status</th>
            <th class="text-right font-medium px-4 py-2">Total</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="q in quotations"
            :key="q.id"
            class="border-t border-n-weak hover:bg-n-alpha-black1 cursor-pointer"
            @click="dialogRef?.open(q)"
          >
            <td class="px-4 py-2.5 font-medium text-n-slate-12">{{ q.number }}</td>
            <td class="px-4 py-2.5 text-n-slate-12">{{ q.company_name || q.contact_name || '—' }}</td>
            <td class="px-4 py-2.5 text-n-slate-11">{{ q.agent_name || '—' }}</td>
            <td class="px-4 py-2.5 text-n-slate-11">{{ fmtData(q.expiration_date) }}</td>
            <td class="px-4 py-2.5">
              <span class="text-xs px-2 py-0.5 rounded-full" :class="STATUS_CLASS[q.status]">
                {{ STATUS_LABEL[q.status] }}
              </span>
            </td>
            <td class="px-4 py-2.5 text-right font-medium text-n-slate-12">{{ fmtValor(q.amount_total) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <QuotationDialog
      ref="dialogRef"
      :is-loading="saving"
      @save="salvar"
      @enviar="enviar"
      @confirmar="confirmar"
      @cancelar="cancelar"
    />
  </div>
</template>
