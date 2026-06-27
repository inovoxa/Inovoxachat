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

ChartJS.register(Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale);

const data = ref(null);
const period = ref('180d');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

const chartData = computed(() => {
  const s = data.value?.semanal || { labels: [], whatsapp: [], formulario: [] };
  return {
    labels: s.labels,
    datasets: [
      { label: 'WhatsApp', data: s.whatsapp, backgroundColor: '#4a9704' },
      { label: 'Formulário', data: s.formulario, backgroundColor: '#baa500' },
    ],
  };
});
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'bottom' } },
};

const catData = computed(() => {
  const c = data.value?.categorias || { labels: [], data: [] };
  return {
    labels: c.labels,
    datasets: [{ label: 'Chamados', data: c.data, backgroundColor: '#baa500' }],
  };
});
const catOptions = {
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
    const resp = await GlpiAPI.getOverview({ period: period.value });
    data.value = resp.data;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">Visão Geral (GLPI)</h1>
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

    <template v-else-if="data">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Total de chamados</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.total }}</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Abertos</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.abertos }}</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Resolvidos</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.resolvidos }}</p>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4">
          <p class="text-xs text-n-slate-11">Execuções no AD</p>
          <p class="text-2xl font-semibold text-n-slate-12">{{ data.cards.execucoesAD }}</p>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div class="rounded-xl bg-n-alpha-black2 p-4 h-80">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Chamados por canal (últimas 4 semanas)</p>
          <div class="h-64">
            <Bar :data="chartData" :options="chartOptions" />
          </div>
        </div>
        <div class="rounded-xl bg-n-alpha-black2 p-4 h-80">
          <p class="text-sm font-medium text-n-slate-12 mb-2">Chamados por categoria</p>
          <div class="h-64">
            <Bar :data="catData" :options="catOptions" />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
