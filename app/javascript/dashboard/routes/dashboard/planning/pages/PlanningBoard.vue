<script setup>
import { ref, computed, onMounted } from 'vue';
import PlanningShiftsAPI from 'dashboard/api/planningShifts';
import { useAlert } from 'dashboard/composables';
import ShiftDialog from '../components/ShiftDialog.vue';

const STATUS = {
  provisorio: { label: 'Provisório', cls: 'bg-slate-500/15 text-slate-500' },
  agendado: { label: 'Agendado', cls: 'bg-blue-500/15 text-blue-600' },
  em_progresso: { label: 'Em progresso', cls: 'bg-yellow-500/15 text-yellow-600' },
  concluido: { label: 'Concluído', cls: 'bg-green-500/15 text-green-600' },
};

const shifts = ref([]);
const date = ref(new Date().toISOString().slice(0, 10));
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const dialogRef = ref(null);

function fmtHora(d) {
  return d ? new Date(d).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) : '—';
}
function statusMeta(s) {
  return STATUS[s] || { label: s, cls: 'bg-slate-500/15 text-slate-500' };
}
const dataLabel = computed(() =>
  new Date(`${date.value}T12:00`).toLocaleDateString('pt-BR', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
  })
);

// Agrupa turnos por recurso (ou "Turno aberto").
const grupos = computed(() => {
  const map = {};
  shifts.value.forEach(s => {
    const nome = s.resource?.name || 'Turnos abertos';
    (map[nome] = map[nome] || []).push(s);
  });
  return Object.entries(map).map(([nome, itens]) => ({ nome, itens }));
});

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await PlanningShiftsAPI.get({ date: date.value });
    shifts.value = data.payload || [];
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function mudarDia(delta) {
  const d = new Date(`${date.value}T12:00`);
  d.setDate(d.getDate() + delta);
  date.value = d.toISOString().slice(0, 10);
  load();
}
function hoje() {
  date.value = new Date().toISOString().slice(0, 10);
  load();
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await PlanningShiftsAPI.update(payload.id, { planning_shift: payload });
    else await PlanningShiftsAPI.create({ planning_shift: payload });
    dialogRef.value?.onSuccess();
    useAlert('Turno salvo.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar o turno.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Planejamento</h1>
      <div class="flex items-center gap-2">
        <button class="rounded-lg border border-n-weak px-2 py-1.5 text-n-slate-12" @click="mudarDia(-1)">←</button>
        <button class="rounded-lg border border-n-weak px-3 py-1.5 text-sm text-n-slate-12" @click="hoje">Hoje</button>
        <button class="rounded-lg border border-n-weak px-2 py-1.5 text-n-slate-12" @click="mudarDia(1)">→</button>
        <button
          class="rounded-lg bg-woot-500 px-4 py-1.5 text-sm font-medium text-white hover:bg-woot-600"
          @click="dialogRef?.open()"
        >
          + Novo turno
        </button>
      </div>
    </div>

    <p class="text-sm text-n-slate-11 capitalize">{{ dataLabel }}</p>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="!shifts.length" class="flex-1 grid place-items-center text-n-slate-11 text-sm">
      Nenhum turno neste dia.
    </div>

    <div v-else class="flex flex-col gap-4">
      <div v-for="g in grupos" :key="g.nome" class="rounded-xl bg-n-alpha-black2 p-4">
        <p class="text-sm font-semibold text-n-slate-12 mb-2">{{ g.nome }}</p>
        <div class="flex flex-col gap-2">
          <div
            v-for="s in g.itens"
            :key="s.id"
            class="flex items-center gap-3 text-sm rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-pointer hover:border-n-slate-7"
            @click="dialogRef?.open(s)"
          >
            <span class="text-n-slate-12 font-medium w-28 shrink-0">
              {{ fmtHora(s.start_at) }}<template v-if="s.end_at"> – {{ fmtHora(s.end_at) }}</template>
            </span>
            <span class="text-n-slate-11 flex-1 truncate">
              {{ s.role || 'Sem função' }}
              <template v-if="s.company_name"> · {{ s.company_name }}</template>
            </span>
            <span class="text-[11px] px-2 py-0.5 rounded-full font-medium" :class="statusMeta(s.status).cls">
              {{ statusMeta(s.status).label }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <ShiftDialog ref="dialogRef" :is-loading="saving" :default-date="date" @save="salvar" />
  </div>
</template>
