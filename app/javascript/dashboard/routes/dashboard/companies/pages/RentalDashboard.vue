<script setup>
import { ref, computed, onMounted } from 'vue';
import RentalDashboardAPI from 'dashboard/api/rentalDashboard';

const data = ref(null);
const loading = ref(true);
const error = ref('');

function fmtValor(v) {
  return Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
function fmtData(d) {
  return d ? new Date(d).toLocaleDateString('pt-BR') : '—';
}

const cards = computed(() => {
  const c = data.value?.cards || {};
  return [
    { label: 'Contratos vencem em 7 dias', valor: c.contratos_vencendo_7 ?? 0, cls: 'text-yellow-600', to: 'contracts_index' },
    { label: 'Contratos vencidos', valor: c.contratos_vencidos ?? 0, cls: 'text-red-600', to: 'contracts_index' },
    { label: 'Empresas inadimplentes', valor: c.inadimplencia_count ?? 0, sub: fmtValor(c.inadimplencia_total), cls: 'text-red-600', to: 'finance_index' },
    { label: 'Faturas esta semana', valor: c.faturas_semana ?? 0, sub: fmtValor(c.faturas_semana_total), cls: 'text-yellow-600', to: 'finance_index' },
    { label: 'Equipamentos alugados', valor: c.equipamentos_alugados ?? 0, cls: 'text-blue-600', to: 'equipments_index' },
    { label: 'Funil em aberto', valor: c.funil_abertas ?? 0, sub: fmtValor(c.funil_valor), cls: 'text-woot-600', to: 'crm_pipeline' },
  ];
});

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const resp = await RentalDashboardAPI.get();
    data.value = resp.data;
  } catch (e) {
    const d = e.response?.data;
    error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-5">
    <h1 class="text-xl font-medium text-n-slate-12">Painel de Controle</h1>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <template v-else-if="data">
      <!-- Cards de alerta -->
      <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
        <router-link
          v-for="c in cards"
          :key="c.label"
          :to="{ name: c.to }"
          class="rounded-xl bg-n-alpha-black2 p-4 flex flex-col gap-1 hover:border-n-slate-7 border border-transparent transition-colors"
        >
          <p class="text-xs text-n-slate-11">{{ c.label }}</p>
          <p class="text-3xl font-bold" :class="c.cls">{{ c.valor }}</p>
          <p v-if="c.sub" class="text-xs text-n-slate-11">{{ c.sub }}</p>
        </router-link>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Timeline de vencimentos -->
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Próximos vencimentos (30 dias)</p>
          <div v-if="data.timeline.length" class="flex flex-col gap-2 max-h-96 overflow-auto">
            <div
              v-for="(t, i) in data.timeline"
              :key="i"
              class="flex items-center gap-3 text-sm border-l-2 pl-3"
              :class="t.tipo === 'fatura' ? 'border-red-500/50' : 'border-yellow-500/50'"
            >
              <span class="text-xs text-n-slate-11 w-16 shrink-0">{{ fmtData(t.data) }}</span>
              <span
                class="text-[10px] px-1.5 py-0.5 rounded-full font-medium shrink-0"
                :class="t.tipo === 'fatura' ? 'bg-red-500/15 text-red-600' : 'bg-yellow-500/15 text-yellow-600'"
              >
                {{ t.tipo === 'fatura' ? 'Fatura' : 'Contrato' }}
              </span>
              <span class="text-n-slate-12 flex-1 truncate">{{ t.empresa || '—' }}</span>
              <span class="text-n-slate-11 shrink-0">{{ fmtValor(t.valor) }}</span>
            </div>
          </div>
          <p v-else class="text-sm text-n-slate-11">Nada vencendo nos próximos 30 dias.</p>
        </div>

        <!-- Empresas que precisam de atenção -->
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Empresas que precisam de atenção</p>
          <div v-if="data.empresas_atencao.length" class="flex flex-col gap-2">
            <div
              v-for="e in data.empresas_atencao"
              :key="e.company_id"
              class="flex items-center justify-between text-sm"
            >
              <span class="text-n-slate-12 truncate flex-1">{{ e.empresa || '—' }}</span>
              <span class="text-xs text-n-slate-11 mx-2">{{ e.qtd }} fatura(s)</span>
              <span class="text-red-600 font-medium shrink-0">{{ fmtValor(e.total) }}</span>
            </div>
          </div>
          <p v-else class="text-sm text-n-slate-11">Nenhuma inadimplência. 🎉</p>
        </div>
      </div>
    </template>
  </div>
</template>
