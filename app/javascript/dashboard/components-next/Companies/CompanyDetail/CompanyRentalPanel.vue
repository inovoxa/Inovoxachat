<script setup>
import { ref, watch, computed } from 'vue';
import ContractsAPI from 'dashboard/api/contracts';
import InvoicesAPI from 'dashboard/api/invoices';

const props = defineProps({
  companyId: { type: Number, required: true },
});

const TABS = [
  { key: 'contratos', label: 'Contratos' },
  { key: 'financeiro', label: 'Financeiro' },
];
const tab = ref('contratos');
const contratos = ref([]);
const faturas = ref([]);
const loading = ref(false);

const CONTRACT_STATUS = {
  ativo: 'bg-green-500/15 text-green-600',
  vencido: 'bg-red-500/15 text-red-600',
  encerrado: 'bg-slate-500/15 text-slate-500',
  renovacao_pendente: 'bg-yellow-500/15 text-yellow-600',
};
const INVOICE_SIT = {
  pendente: 'bg-yellow-500/15 text-yellow-600',
  atrasado: 'bg-red-500/15 text-red-600',
  pago: 'bg-green-500/15 text-green-600',
};

function fmtValor(v) {
  return Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
function fmtData(d) {
  return d ? new Date(d).toLocaleDateString('pt-BR') : '—';
}

const resumo = computed(() => {
  const ativos = contratos.value.filter(c => c.status === 'ativo').length;
  const devedor = faturas.value
    .filter(f => f.situacao !== 'pago')
    .reduce((s, f) => s + Number(f.amount || 0), 0);
  const proximo = contratos.value
    .filter(c => c.status === 'ativo' && c.end_date)
    .sort((a, b) => new Date(a.end_date) - new Date(b.end_date))[0];
  return { ativos, devedor, proximo: proximo?.end_date };
});

async function load() {
  if (!props.companyId) return;
  loading.value = true;
  try {
    const [c, f] = await Promise.allSettled([
      ContractsAPI.get({ company_id: props.companyId }),
      InvoicesAPI.get({ company_id: props.companyId }),
    ]);
    contratos.value = c.value?.data?.payload || [];
    faturas.value = f.value?.data?.payload || [];
  } finally {
    loading.value = false;
  }
}

watch(() => props.companyId, load, { immediate: true });
</script>

<template>
  <section class="flex flex-col gap-3 pt-6 border-t border-n-strong">
    <h6 class="text-base font-medium text-n-slate-12">Locação</h6>

    <!-- Resumo -->
    <div class="grid grid-cols-3 gap-3">
      <div class="rounded-lg bg-n-alpha-black2 p-3">
        <p class="text-xs text-n-slate-11">Contratos ativos</p>
        <p class="text-xl font-semibold text-n-slate-12">{{ resumo.ativos }}</p>
      </div>
      <div class="rounded-lg bg-n-alpha-black2 p-3">
        <p class="text-xs text-n-slate-11">Saldo devedor</p>
        <p class="text-xl font-semibold" :class="resumo.devedor > 0 ? 'text-red-600' : 'text-n-slate-12'">
          {{ fmtValor(resumo.devedor) }}
        </p>
      </div>
      <div class="rounded-lg bg-n-alpha-black2 p-3">
        <p class="text-xs text-n-slate-11">Próximo vencimento</p>
        <p class="text-xl font-semibold text-n-slate-12">{{ fmtData(resumo.proximo) }}</p>
      </div>
    </div>

    <!-- Abas -->
    <div class="flex items-center gap-1.5">
      <button
        v-for="t in TABS"
        :key="t.key"
        class="text-sm px-3 py-1.5 rounded-lg border transition-colors"
        :class="
          tab === t.key
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'border-n-weak text-n-slate-11 hover:text-n-slate-12'
        "
        @click="tab = t.key"
      >
        {{ t.label }}
      </button>
    </div>

    <p v-if="loading" class="text-n-slate-11 text-sm">Carregando…</p>

    <!-- Contratos -->
    <div v-else-if="tab === 'contratos'" class="rounded-xl border border-n-weak overflow-hidden">
      <table v-if="contratos.length" class="w-full text-sm">
        <thead class="bg-n-solid-2 text-left text-n-slate-11">
          <tr>
            <th class="font-normal px-3 py-2">#</th>
            <th class="font-normal px-3 py-2">Período</th>
            <th class="font-normal px-3 py-2">Valor</th>
            <th class="font-normal px-3 py-2">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in contratos" :key="c.id" class="border-t border-n-weak">
            <td class="px-3 py-2 text-n-slate-11">#{{ c.id }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ fmtData(c.start_date) }} – {{ fmtData(c.end_date) }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ fmtValor(c.value) }}</td>
            <td class="px-3 py-2">
              <span class="text-[11px] px-2 py-0.5 rounded-full font-medium" :class="CONTRACT_STATUS[c.status]">
                {{ c.status }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else class="text-sm text-n-slate-11 p-3">Nenhum contrato para esta empresa.</p>
    </div>

    <!-- Financeiro -->
    <div v-else class="rounded-xl border border-n-weak overflow-hidden">
      <table v-if="faturas.length" class="w-full text-sm">
        <thead class="bg-n-solid-2 text-left text-n-slate-11">
          <tr>
            <th class="font-normal px-3 py-2">Vencimento</th>
            <th class="font-normal px-3 py-2">Valor</th>
            <th class="font-normal px-3 py-2">Situação</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="f in faturas" :key="f.id" class="border-t border-n-weak">
            <td class="px-3 py-2" :class="f.situacao === 'atrasado' ? 'text-red-500 font-medium' : 'text-n-slate-11'">
              {{ fmtData(f.due_date) }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">{{ fmtValor(f.amount) }}</td>
            <td class="px-3 py-2">
              <span class="text-[11px] px-2 py-0.5 rounded-full font-medium" :class="INVOICE_SIT[f.situacao]">
                {{ f.situacao }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-else class="text-sm text-n-slate-11 p-3">Nenhuma fatura para esta empresa.</p>
    </div>
  </section>
</template>
