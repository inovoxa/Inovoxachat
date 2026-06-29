<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';
import { adIcon, tempoRelativo, fmtDuracao } from '../helpers';
import PeriodFilter from '../components/PeriodFilter.vue';
import TicketDetailModal from '../components/TicketDetailModal.vue';

const POLL_MS = 15000; // atualização "ao vivo"

const eventos = ref([]);
const kpis = ref({});
const tipos = ref([]);
const filterParams = ref({ period: '90d' });
const search = ref('');
const tipo = ref('');
const resultado = ref('');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');
const selectedId = ref(null);
const atualizadoEm = ref(null);
const expandidos = ref({});
let searchTimer = null;
let pollTimer = null;

const kpiCards = computed(() => {
  const k = kpis.value || {};
  return [
    { label: 'Execuções no período', value: k.total ?? 0 },
    { label: 'Hoje', value: k.hoje ?? 0 },
    {
      label: 'Taxa de sucesso',
      value: k.taxaSucesso != null ? `${k.taxaSucesso}%` : '—',
      accent: true,
    },
    { label: 'Última execução', value: tempoRelativo(k.ultima) },
  ];
});

// Agrupa os eventos por dia (Hoje / Ontem / dd/mm/aaaa) preservando a ordem.
const grupos = computed(() => {
  const hoje = new Date();
  hoje.setHours(0, 0, 0, 0);
  const ontem = new Date(hoje);
  ontem.setDate(ontem.getDate() - 1);
  const out = [];
  let atual = null;
  (eventos.value || []).forEach(ev => {
    const d = new Date(ev.at);
    d.setHours(0, 0, 0, 0);
    let label;
    if (d.getTime() === hoje.getTime()) label = 'Hoje';
    else if (d.getTime() === ontem.getTime()) label = 'Ontem';
    else label = new Date(ev.at).toLocaleDateString('pt-BR');
    if (!atual || atual.label !== label) {
      atual = { label, itens: [] };
      out.push(atual);
    }
    atual.itens.push(ev);
  });
  return out;
});

function horaCurta(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

async function load(silent = false) {
  if (!silent) loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getAtividade({
      ...filterParams.value,
      search: search.value || undefined,
      tipo: tipo.value || undefined,
      resultado: resultado.value || undefined,
    });
    eventos.value = data.eventos || [];
    kpis.value = data.kpis || {};
    tipos.value = data.tipos || [];
    atualizadoEm.value = data.generatedAt;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else if (!silent) error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function onFilter(params) {
  filterParams.value = params;
  load();
}

function onSearch() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => load(), 400);
}

function toggle(id) {
  expandidos.value = { ...expandidos.value, [id]: !expandidos.value[id] };
}

onMounted(() => {
  load();
  pollTimer = setInterval(() => load(true), POLL_MS);
});
onBeforeUnmount(() => clearInterval(pollTimer));
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12 flex items-center gap-2">
        Atividade ao vivo
        <span class="flex items-center gap-1.5 text-xs text-n-slate-11 font-normal">
          <span class="relative flex h-2 w-2">
            <span
              class="animate-ping absolute inline-flex h-full w-full rounded-full bg-woot-500 opacity-75"
            />
            <span class="relative inline-flex rounded-full h-2 w-2 bg-woot-500" />
          </span>
          ao vivo
          <span v-if="atualizadoEm">· {{ tempoRelativo(atualizadoEm) }}</span>
        </span>
      </h1>
      <div class="flex items-center gap-2 flex-wrap">
        <input
          v-model="search"
          type="search"
          placeholder="Buscar solicitante, login, setor ou #"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-60"
          @input="onSearch"
        />
        <select
          v-model="tipo"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12 max-w-44"
          @change="load()"
        >
          <option value="">Todos os tipos</option>
          <option v-for="t in tipos" :key="t" :value="t">{{ t }}</option>
        </select>
        <select
          v-model="resultado"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
          @change="load()"
        >
          <option value="">Sucesso + falha</option>
          <option value="sucesso">Só sucesso</option>
          <option value="falha">Só falha</option>
        </select>
        <PeriodFilter @change="onFilter" />
      </div>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div
        v-for="c in kpiCards"
        :key="c.label"
        class="rounded-xl bg-n-alpha-black2 p-4 flex flex-col gap-1"
      >
        <p class="text-xs text-n-slate-11">{{ c.label }}</p>
        <p
          class="text-2xl font-semibold"
          :class="c.accent ? 'text-woot-500' : 'text-n-slate-12'"
        >
          {{ c.value }}
        </p>
      </div>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">
        Configurar agora
      </router-link>
    </div>

    <div
      v-else-if="!eventos.length"
      class="flex-1 grid place-items-center text-n-slate-11 text-sm"
    >
      Nenhuma execução no AD no período selecionado.
    </div>

    <!-- Timeline -->
    <div v-else class="flex-1 overflow-y-auto pr-1 flex flex-col gap-5">
      <div v-for="g in grupos" :key="g.label" class="flex flex-col gap-2">
        <p
          class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide sticky top-0 bg-n-background py-1"
        >
          {{ g.label }}
        </p>
        <div
          v-for="ev in g.itens"
          :key="ev.id"
          class="rounded-lg bg-n-alpha-black2 border border-n-weak hover:border-n-slate-7 transition-colors"
        >
          <div class="flex items-start gap-3 p-3 cursor-pointer" @click="toggle(ev.id)">
            <span
              class="text-lg leading-none mt-0.5 w-8 h-8 grid place-items-center rounded-full shrink-0"
              :class="ev.sucesso ? 'bg-green-500/15' : 'bg-red-500/15'"
            >
              {{ adIcon(ev.categoriaId, ev.acao) }}
            </span>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <span class="text-sm font-medium text-n-slate-12 truncate">
                  {{ ev.acao || ev.categoria }}
                </span>
                <span
                  class="text-[10px] px-1.5 py-0.5 rounded-full font-medium"
                  :class="
                    ev.sucesso
                      ? 'bg-green-500/15 text-green-600'
                      : 'bg-red-500/15 text-red-600'
                  "
                >
                  {{ ev.sucesso ? 'Sucesso' : 'Falha' }}
                </span>
              </div>
              <p class="text-xs text-n-slate-11 truncate">
                {{ ev.solicitante || '—' }}
                <template v-if="ev.setor"> · {{ ev.setor }}</template>
                <template v-if="ev.login"> · {{ ev.login }}</template>
              </p>
            </div>
            <div class="text-right shrink-0">
              <p class="text-xs text-n-slate-11" :title="ev.at">{{ horaCurta(ev.at) }}</p>
              <p class="text-[10px] text-n-slate-10">#{{ ev.ticketId }}</p>
            </div>
          </div>

          <!-- Detalhe expandido -->
          <div
            v-if="expandidos[ev.id]"
            class="px-3 pb-3 pt-0 ml-11 flex flex-col gap-1.5 text-xs"
          >
            <p class="text-n-slate-11">{{ ev.categoria }}</p>
            <div
              v-for="d in ev.detalhes"
              :key="d.label"
              class="flex gap-2"
            >
              <span class="text-n-slate-10 w-20 shrink-0">{{ d.label }}</span>
              <span class="text-n-slate-12 break-all">{{ d.valor }}</span>
            </div>
            <div class="flex gap-4 text-n-slate-10 mt-1">
              <span v-if="ev.esperaSeg != null">
                ⏱ Espera até execução: {{ fmtDuracao(ev.esperaSeg) }}
              </span>
              <button
                type="button"
                class="text-woot-500 underline"
                @click.stop="selectedId = ev.ticketId"
              >
                Ver chamado
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <TicketDetailModal
      v-if="selectedId"
      :ticket-id="selectedId"
      @close="selectedId = null"
    />
  </div>
</template>
