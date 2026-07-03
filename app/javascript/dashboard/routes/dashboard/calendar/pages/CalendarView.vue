<script setup>
import { ref, computed, onMounted } from 'vue';
import MeetingsAPI from 'dashboard/api/meetings';
import { useAlert } from 'dashboard/composables';
import MeetingDialog from '../components/MeetingDialog.vue';

const DIAS = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];

const meetings = ref([]);
const cursor = ref(new Date());
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const dialogRef = ref(null);

function startOfWeek(d) {
  const x = new Date(d);
  x.setDate(x.getDate() - x.getDay());
  x.setHours(0, 0, 0, 0);
  return x;
}
function ymd(d) {
  return d.toISOString().slice(0, 10);
}
function fmtHora(d) {
  return d ? new Date(d).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) : '';
}

const semana = computed(() => {
  const ini = startOfWeek(cursor.value);
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(ini);
    d.setDate(d.getDate() + i);
    return d;
  });
});
const periodoLabel = computed(() => {
  const s = semana.value;
  const f = { day: '2-digit', month: 'short' };
  return `${s[0].toLocaleDateString('pt-BR', f)} – ${s[6].toLocaleDateString('pt-BR', f)}`;
});
const hojeYmd = ymd(new Date());

function reunioesDoDia(d) {
  const key = ymd(d);
  return meetings.value
    .filter(m => (m.start_at || '').slice(0, 10) === key)
    .sort((a, b) => new Date(a.start_at) - new Date(b.start_at));
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const from = semana.value[0];
    const to = new Date(semana.value[6]);
    to.setDate(to.getDate() + 1);
    const { data } = await MeetingsAPI.get({ from: from.toISOString(), to: to.toISOString() });
    meetings.value = data.payload || [];
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

function mudarSemana(delta) {
  const d = new Date(cursor.value);
  d.setDate(d.getDate() + delta * 7);
  cursor.value = d;
  load();
}
function hoje() {
  cursor.value = new Date();
  load();
}

function novo(dia) {
  dialogRef.value?.open(dia ? { defaultStart: `${ymd(dia)}T09:00` } : {});
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await MeetingsAPI.update(payload.id, { meeting: payload });
    else await MeetingsAPI.create({ meeting: payload });
    dialogRef.value?.onSuccess();
    useAlert('Reunião salva.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar a reunião.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Calendário · Reuniões</h1>
      <div class="flex items-center gap-2">
        <button class="rounded-lg border border-n-weak px-2 py-1.5 text-n-slate-12" @click="mudarSemana(-1)">←</button>
        <button class="rounded-lg border border-n-weak px-3 py-1.5 text-sm text-n-slate-12" @click="hoje">Hoje</button>
        <button class="rounded-lg border border-n-weak px-2 py-1.5 text-n-slate-12" @click="mudarSemana(1)">→</button>
        <span class="text-sm text-n-slate-11 mx-1">{{ periodoLabel }}</span>
        <button
          class="rounded-lg bg-woot-500 px-4 py-1.5 text-sm font-medium text-white hover:bg-woot-600"
          @click="novo()"
        >
          + Nova reunião
        </button>
      </div>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else class="grid grid-cols-7 gap-2 flex-1 overflow-auto">
      <div
        v-for="(d, i) in semana"
        :key="i"
        class="flex flex-col rounded-xl bg-n-alpha-black2 p-2 gap-2 min-h-40"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs text-n-slate-11">{{ DIAS[i] }}</span>
          <span
            class="text-sm font-semibold w-6 h-6 grid place-items-center rounded-full"
            :class="ymd(d) === hojeYmd ? 'bg-red-500 text-white' : 'text-n-slate-12'"
          >
            {{ d.getDate() }}
          </span>
        </div>
        <div class="flex flex-col gap-1.5 flex-1">
          <div
            v-for="m in reunioesDoDia(d)"
            :key="m.id"
            class="rounded-lg bg-woot-500/15 border-l-2 border-woot-500 px-2 py-1 cursor-pointer hover:bg-woot-500/25"
            @click="dialogRef?.open(m)"
          >
            <p class="text-[11px] text-woot-700 font-medium">{{ fmtHora(m.start_at) }}</p>
            <p class="text-xs text-n-slate-12 truncate">{{ m.title }}</p>
          </div>
        </div>
        <button
          class="text-[11px] text-n-slate-11 hover:text-woot-500"
          @click="novo(d)"
        >
          + reunião
        </button>
      </div>
    </div>

    <MeetingDialog ref="dialogRef" :is-loading="saving" @save="salvar" />
  </div>
</template>
