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
const filterParams = ref({ period: '180d' });
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const chartData = computed(() => {
  const h = data.value?.horasMensais || { labels: [], data: [] };
  return {
    labels: h.labels,
    datasets: [{ label: 'Horas economizadas', data: h.data, backgroundColor: '#4a9704' }],
  };
});
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } },
};

const opsData = computed(() => {
  const ops = data.value?.operacoes || [];
  return {
    labels: ops.map(o => o.nome),
    datasets: [{ label: 'Operações', data: ops.map(o => o.total), backgroundColor: '#4a9704' }],
  };
});
const opsOptions = {
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y',
  plugins: { legend: { display: false } },
};

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
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">Agente IA (GLPI)</h1>
      <PeriodFilter @change="onFilter" />
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">
        Configurar agora
      </router-link>
    </div>

    <p v-else-if="error" class="text-red-500">{{ error }}</p>

    <template v-else-if="data">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Conversas</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.conversas }}</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Sem intervenção humana</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.semHumanoPct ?? '—' }}%</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Tempo médio de execução</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.tempoMedio }}</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Execuções no AD</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.execucoesAD }}</p>
        </div>
      </div>

      <div class="rounded-xl bg-n-alpha-black2 p-4">
        <p class="text-sm font-medium text-n-slate-12 mb-2">ROI estimado</p>
        <p class="text-sm text-n-slate-11">
          {{ data.roi.horas }} h economizadas ·
          R$ {{ data.roi.economia }} ({{ data.roi.minPorOp }} min/op · R$ {{ data.roi.custoHora }}/h)
        </p>
      </div>

      <div class="rounded-xl bg-n-alpha-black2 p-4 h-72">
        <p class="text-sm font-medium text-n-slate-12 mb-2">Horas economizadas por dia</p>
        <div class="h-56">
          <Bar :data="chartData" :options="chartOptions" />
        </div>
      </div>

      <div class="rounded-xl bg-n-alpha-black2 p-4">
        <p class="text-sm font-medium text-n-slate-12 mb-2">Operações por tipo</p>
        <div v-if="data.operacoes.length" class="h-56 mb-3">
          <Bar :data="opsData" :options="opsOptions" />
        </div>
        <div
          v-for="op in data.operacoes"
          :key="op.nome"
          class="flex justify-between text-sm py-1 border-b border-n-weak/40"
        >
          <span class="text-n-slate-11">{{ op.nome }}</span>
          <span class="text-n-slate-12">{{ op.total }}</span>
        </div>
        <p v-if="!data.operacoes.length" class="text-sm text-n-slate-11">Sem dados no período.</p>
      </div>
    </template>
  </div>
</template>
