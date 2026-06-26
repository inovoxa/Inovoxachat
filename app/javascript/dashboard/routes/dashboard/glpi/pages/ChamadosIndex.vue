<script setup>
import { ref, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const tickets = ref([]);
const total = ref(0);
const period = ref('30d');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');

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
            class="border-b border-n-weak/50 hover:bg-n-alpha-black2"
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
            <td colspan="7" class="py-6 text-center text-n-slate-11">
              Nenhum chamado no período.
            </td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>
