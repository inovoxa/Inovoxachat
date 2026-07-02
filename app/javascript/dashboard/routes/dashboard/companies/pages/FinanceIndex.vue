<script setup>
import { ref, onMounted } from 'vue';
import InvoicesAPI from 'dashboard/api/invoices';
import { useAlert } from 'dashboard/composables';
import InvoiceCreateDialog from 'dashboard/components-next/Companies/InvoiceCreateDialog.vue';

const FILTROS = [
  { key: 'pendentes', label: 'Pendentes' },
  { key: 'inadimplencia', label: 'Inadimplência' },
  { key: 'pagas', label: 'Pagas' },
  { key: 'todas', label: 'Todas' },
];
const SITUACAO = {
  pendente: { label: 'Pendente', cls: 'bg-yellow-500/15 text-yellow-600' },
  atrasado: { label: 'Atrasado', cls: 'bg-red-500/15 text-red-600' },
  pago: { label: 'Pago', cls: 'bg-green-500/15 text-green-600' },
};

const faturas = ref([]);
const loading = ref(true);
const error = ref('');
const filtro = ref('pendentes');
const saving = ref(false);
const dialogRef = ref(null);

function fmtData(d) {
  return d ? new Date(d).toLocaleDateString('pt-BR') : '—';
}
function fmtValor(v) {
  return v != null
    ? Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
    : '—';
}
function sitMeta(s) {
  return SITUACAO[s] || { label: s, cls: 'bg-slate-500/15 text-slate-500' };
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const params = filtro.value === 'todas' ? {} : { filter: filtro.value };
    const { data } = await InvoicesAPI.get(params);
    faturas.value = data.payload || [];
  } catch (e) {
    const d = e.response?.data;
    error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
  } finally {
    loading.value = false;
  }
}

function setFiltro(k) {
  filtro.value = k;
  load();
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await InvoicesAPI.update(payload.id, { invoice: payload });
    else await InvoicesAPI.create({ invoice: payload });
    dialogRef.value?.onSuccess();
    useAlert('Fatura salva.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar a fatura.');
  } finally {
    saving.value = false;
  }
}

async function pagar(f) {
  saving.value = true;
  try {
    await InvoicesAPI.pagar(f.id);
    useAlert('Fatura marcada como paga.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao registrar pagamento.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-xl font-medium text-n-slate-12">Financeiro</h1>
      <button
        class="rounded-lg bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600"
        @click="dialogRef?.open()"
      >
        + Nova fatura
      </button>
    </div>

    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="f in FILTROS"
        :key="f.key"
        class="text-sm px-3 py-1.5 rounded-lg border transition-colors"
        :class="
          filtro === f.key
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'border-n-weak text-n-slate-11 hover:text-n-slate-12'
        "
        @click="setFiltro(f.key)"
      >
        {{ f.label }}
      </button>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div
      v-else-if="!faturas.length"
      class="flex-1 grid place-items-center text-n-slate-11 text-sm"
    >
      Nenhuma fatura para este filtro.
    </div>

    <div v-else class="flex-1 overflow-auto rounded-xl border border-n-weak">
      <table class="w-full text-sm">
        <thead class="sticky top-0 bg-n-solid-2">
          <tr class="text-left text-n-slate-11">
            <th class="font-normal px-3 py-2">Empresa</th>
            <th class="font-normal px-3 py-2">Vencimento</th>
            <th class="font-normal px-3 py-2">Valor</th>
            <th class="font-normal px-3 py-2">Situação</th>
            <th class="font-normal px-3 py-2"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="f in faturas" :key="f.id" class="border-t border-n-weak hover:bg-n-alpha-black2">
            <td class="px-3 py-2 text-n-slate-12">{{ f.company_name || '—' }}</td>
            <td class="px-3 py-2" :class="f.situacao === 'atrasado' ? 'text-red-500 font-medium' : 'text-n-slate-11'">
              {{ fmtData(f.due_date) }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">{{ fmtValor(f.amount) }}</td>
            <td class="px-3 py-2">
              <span class="text-[11px] px-2 py-0.5 rounded-full font-medium" :class="sitMeta(f.situacao).cls">
                {{ sitMeta(f.situacao).label }}
              </span>
            </td>
            <td class="px-3 py-2 text-right">
              <button
                v-if="f.situacao !== 'pago'"
                class="text-xs text-woot-500 hover:underline disabled:opacity-50"
                :disabled="saving"
                @click="pagar(f)"
              >
                Registrar pagamento
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <InvoiceCreateDialog ref="dialogRef" :is-loading="saving" @save="salvar" />
  </div>
</template>
