<script setup>
import { ref, computed, onMounted } from 'vue';
import { Bar } from 'vue-chartjs';
import {
  Chart as ChartJS,
  Title,
  Tooltip,
  Legend,
  BarElement,
  CategoryScale,
  LinearScale,
} from 'chart.js';
import GlpiAPI from 'dashboard/api/glpi';
import PeriodFilter from '../components/PeriodFilter.vue';

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale);

const data = ref(null);
const filterParams = ref({ period: '90d' });
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const cards = computed(() => {
  const c = data.value?.cards || {};
  return [
    { label: 'Conversas', value: c.conversas ?? 0 },
    { label: 'Sem intervenção humana', value: c.semHumanoPct != null ? `${c.semHumanoPct}%` : '—' },
    { label: 'Tempo médio de execução', value: c.tempoMedio || '—' },
    { label: 'Execuções no AD', value: c.execucoesAD ?? 0 },
  ];
});

const horasData = computed(() => {
  const h = data.value?.horasMensais || { labels: [], data: [] };
  return {
    labels: h.labels,
    datasets: [{ label: 'Horas', data: h.data, backgroundColor: '#4a9704', borderRadius: 4 }],
  };
});
const hasHoras = computed(() => (data.value?.horasMensais?.data || []).some(v => v > 0));

const opsData = computed(() => {
  const ops = data.value?.operacoes || [];
  return {
    labels: ops.map(o => o.nome),
    datasets: [{ label: 'Operações', data: ops.map(o => o.total), backgroundColor: '#5B7FDE', borderRadius: 4 }],
  };
});
const hasOps = computed(() => (data.value?.operacoes || []).length > 0);
const glpiKpis = computed(() => data.value?.glpiKpis || {});

const barOpts = { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } };
const barOptsH = { ...barOpts, indexAxis: 'y' };

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const resp = await GlpiAPI.getAgente({ ...filterParams.value });
    data.value = resp.data;
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

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-5">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Agente IA (GLPI)</h1>
      <PeriodFilter @change="onFilter" />
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">Configurar agora</router-link>
    </div>

    <p v-else-if="error" class="text-red-500">{{ error }}</p>

    <template v-else-if="data">
      <!-- KPIs -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div v-for="c in cards" :key="c.label" class="rounded-xl bg-n-alpha-black2 p-4 flex flex-col gap-1">
          <p class="text-xs text-n-slate-11">{{ c.label }}</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ c.value }}</p>
        </div>
      </div>

      <!-- ROI -->
      <div class="rounded-xl p-5 flex flex-wrap items-center gap-6 bg-woot-50 border border-woot-100">
        <div>
          <p class="text-xs text-n-slate-11">Horas economizadas</p>
          <p class="text-3xl font-bold text-woot-700">{{ data.roi.horas }} h</p>
        </div>
        <div>
          <p class="text-xs text-n-slate-11">Economia estimada</p>
          <p class="text-3xl font-bold text-woot-700">R$ {{ data.roi.economia }}</p>
        </div>
        <p class="text-xs text-n-slate-11 ml-auto">
          Base: {{ data.roi.minPorOp }} min por operação · R$ {{ data.roi.custoHora }}/hora
        </p>
      </div>

      <!-- Resultados no GLPI -->
      <div class="rounded-xl bg-n-alpha-black2 p-4">
        <p class="text-sm font-medium text-n-slate-12 mb-3">
          Resultados no GLPI — chamados gerados pela automação
        </p>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <p class="text-xs text-n-slate-11">Chamados gerados</p>
            <p class="text-xl font-semibold text-n-slate-12">{{ glpiKpis.gerados ?? 0 }}</p>
          </div>
          <div>
            <p class="text-xs text-n-slate-11">Resolvidos</p>
            <p class="text-xl font-semibold text-n-slate-12">{{ glpiKpis.resolvidos ?? 0 }}</p>
          </div>
          <div>
            <p class="text-xs text-n-slate-11">Taxa de resolução</p>
            <p class="text-xl font-semibold text-woot-700">
              {{ glpiKpis.taxaResolucao != null ? glpiKpis.taxaResolucao + '%' : '—' }}
            </p>
          </div>
          <div>
            <p class="text-xs text-n-slate-11">Tempo médio de resolução</p>
            <p class="text-xl font-semibold text-n-slate-12">{{ glpiKpis.tempoMedioResolucao || '—' }}</p>
          </div>
        </div>
      </div>

      <!-- Gráficos -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div class="rounded-xl bg-n-alpha-black2 p-4 h-80 flex flex-col">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Horas economizadas por dia</p>
          <div v-if="hasHoras" class="flex-1 min-h-0">
            <Bar :data="horasData" :options="barOpts" />
          </div>
          <p v-else class="flex-1 grid place-items-center text-sm text-n-slate-11">
            Sem execuções de AD no período.
          </p>
        </div>

        <div class="rounded-xl bg-n-alpha-black2 p-4 h-80 flex flex-col">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Operações por tipo</p>
          <div v-if="hasOps" class="flex-1 min-h-0">
            <Bar :data="opsData" :options="barOptsH" />
          </div>
          <p v-else class="flex-1 grid place-items-center text-sm text-n-slate-11">
            Sem operações no período.
          </p>
        </div>
      </div>
    </template>
  </div>
</template>
