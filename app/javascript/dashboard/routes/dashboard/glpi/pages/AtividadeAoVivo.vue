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
const falhasAberto = ref(true);
const somAtivo = ref(localStorage.getItem('glpi_atividade_som') === '1');
const novos = ref(new Set()); // chaves destacadas (execuções recém-chegadas)
let searchTimer = null;
let pollTimer = null;
let vistos = null; // Set de chaves já conhecidas (null = ainda não carregou)
let highlightTimer = null;

const evKey = ev => `${ev.ticketId}-${ev.at}`;

// Bip curto via Web Audio (sem arquivo) ao chegar execução nova.
// 'sucesso' = tom limpo e agudo; 'falha' = tom de alerta grave e descendente.
function bip(tipo = 'sucesso') {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    const t = ctx.currentTime;
    if (tipo === 'falha') {
      osc.type = 'square';
      osc.frequency.setValueAtTime(440, t);
      osc.frequency.setValueAtTime(330, t + 0.16); // dois tons descendentes = alerta
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.18, t + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.48);
      osc.start(t);
      osc.stop(t + 0.5);
    } else {
      osc.type = 'sine';
      osc.frequency.value = 880;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(0.2, t + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.25);
      osc.start(t);
      osc.stop(t + 0.26);
    }
    osc.onended = () => ctx.close();
  } catch (e) {
    /* áudio indisponível — ignora */
  }
}

function toggleSom() {
  somAtivo.value = !somAtivo.value;
  localStorage.setItem('glpi_atividade_som', somAtivo.value ? '1' : '0');
  if (somAtivo.value) bip(); // confirma e destrava o áudio (gesto do usuário)
}

// Detecta execuções novas comparando com o que já era conhecido.
// Só alerta em recargas do polling (silent); carga inicial/troca de filtro só sincroniza.
function detectarNovos(lista, silent) {
  const chaves = lista.map(evKey);
  if (!silent || vistos === null) {
    vistos = new Set(chaves);
    novos.value = new Set();
    return;
  }
  const recem = chaves.filter(k => !vistos.has(k));
  chaves.forEach(k => vistos.add(k));
  if (!recem.length) return;
  const recemSet = new Set(recem);
  novos.value = new Set([...novos.value, ...recem]);
  if (somAtivo.value) {
    const temFalha = lista.some(e => recemSet.has(evKey(e)) && !e.sucesso);
    bip(temFalha ? 'falha' : 'sucesso');
  }
  clearTimeout(highlightTimer);
  highlightTimer = setTimeout(() => {
    novos.value = new Set();
  }, 8000);
}

const falhas = computed(() => (eventos.value || []).filter(e => !e.sucesso));

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
    detectarNovos(eventos.value, silent);
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
onBeforeUnmount(() => {
  clearInterval(pollTimer);
  clearTimeout(highlightTimer);
});
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
        <button
          type="button"
          class="text-base leading-none p-1 rounded-md hover:bg-n-alpha-black2 text-n-slate-11"
          :title="somAtivo ? 'Som de alerta ligado' : 'Som de alerta desligado'"
          @click="toggleSom"
        >
          {{ somAtivo ? '🔔' : '🔕' }}
        </button>
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

    <!-- Falhas em destaque -->
    <div
      v-if="falhas.length"
      class="rounded-xl border border-red-500/40 bg-red-500/10 overflow-hidden shrink-0"
    >
      <button
        type="button"
        class="w-full flex items-center gap-2 px-4 py-2.5 text-left"
        @click="falhasAberto = !falhasAberto"
      >
        <span class="text-red-600">⚠</span>
        <span class="text-sm font-medium text-red-600">
          {{ falhas.length }}
          {{ falhas.length === 1 ? 'execução falhou' : 'execuções falharam' }}
          no período
        </span>
        <span class="ml-auto text-xs text-red-600/80">
          {{ falhasAberto ? 'ocultar' : 'mostrar' }}
        </span>
      </button>
      <div v-if="falhasAberto" class="px-4 pb-3 flex flex-col gap-1.5">
        <button
          v-for="f in falhas"
          :key="evKey(f)"
          type="button"
          class="flex items-start gap-2 text-left text-xs hover:bg-red-500/10 rounded-md px-2 py-1 -mx-2"
          @click="selectedId = f.ticketId"
        >
          <span class="shrink-0">{{ adIcon(f.categoriaId, f.acao) }}</span>
          <span class="text-n-slate-12 font-medium shrink-0">#{{ f.ticketId }}</span>
          <span class="text-n-slate-11 shrink-0">{{ f.acao || f.categoria }}</span>
          <span v-if="f.erro" class="text-red-600 truncate">— {{ f.erro }}</span>
          <span class="ml-auto text-n-slate-10 shrink-0">{{ horaCurta(f.at) }}</span>
        </button>
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
          :key="evKey(ev)"
          class="rounded-lg bg-n-alpha-black2 border transition-colors"
          :class="
            novos.has(evKey(ev))
              ? 'border-woot-500 ring-1 ring-woot-500/40 animate-pulse'
              : 'border-n-weak hover:border-n-slate-7'
          "
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
                <span
                  v-if="novos.has(evKey(ev))"
                  class="text-[10px] px-1.5 py-0.5 rounded-full bg-woot-500 text-white font-medium"
                >
                  novo
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
