<script setup>
import { reactive, ref, computed, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import OpportunitiesAPI from 'dashboard/api/opportunities';
import { useAlert } from 'dashboard/composables';
import OpportunityDialog from '../components/OpportunityDialog.vue';

const COLUMNS = [
  { key: 'novo', label: 'Novo', color: '#5B7FDE' },
  { key: 'qualificado', label: 'Qualificado', color: '#a06bff' },
  { key: 'proposta', label: 'Proposta', color: '#FFB454' },
  { key: 'ganho', label: 'Ganho', color: '#3ddc97' },
];

const columns = reactive({});
COLUMNS.forEach(c => {
  columns[c.key] = [];
});
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const dialogRef = ref(null);

function avatarInicial(o) {
  return (o.contact?.name || o.name || '?').trim().charAt(0).toUpperCase();
}
function corAvatar(txt) {
  let h = 0;
  for (let i = 0; i < txt.length; i += 1) h = (h * 31 + txt.charCodeAt(i)) % 360;
  return `hsl(${h}, 55%, 45%)`;
}
function fmtValor(v) {
  return Number(v || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}
function totalColuna(key) {
  return fmtValor((columns[key] || []).reduce((s, o) => s + Number(o.expected_value || 0), 0));
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await OpportunitiesAPI.get();
    COLUMNS.forEach(c => {
      columns[c.key] = [];
    });
    (data.payload || []).forEach(o => {
      (columns[o.stage] || columns.novo).push(o);
    });
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

async function onChange(stage, evt) {
  if (!evt.added) return;
  const card = evt.added.element;
  saving.value = true;
  try {
    await OpportunitiesAPI.move(card.id, stage, evt.added.newIndex);
    if (stage === 'ganho') {
      // gerar contrato ao ganhar
      await OpportunitiesAPI.ganhar(card.id, true);
      useAlert('Oportunidade ganha! Contrato gerado.');
    }
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
    await load();
  } finally {
    saving.value = false;
  }
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await OpportunitiesAPI.update(payload.id, { opportunity: payload });
    else await OpportunitiesAPI.create({ opportunity: payload });
    dialogRef.value?.onSuccess();
    useAlert('Oportunidade salva.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar a oportunidade.');
  } finally {
    saving.value = false;
  }
}

async function onMoveStage({ id, stage }) {
  saving.value = true;
  try {
    await OpportunitiesAPI.move(id, stage);
    if (stage === 'ganho') {
      await OpportunitiesAPI.ganhar(id, true);
      useAlert('Oportunidade ganha! Contrato gerado.');
    }
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao mover a oportunidade.');
  } finally {
    saving.value = false;
  }
}

async function acao(op, tipo) {
  saving.value = true;
  try {
    if (tipo === 'ganhar') await OpportunitiesAPI.ganhar(op.id, true);
    else await OpportunitiesAPI.perder(op.id);
    dialogRef.value?.onSuccess();
    useAlert(tipo === 'ganhar' ? 'Oportunidade ganha! Contrato gerado.' : 'Oportunidade marcada como perdida.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro na operação.');
  } finally {
    saving.value = false;
  }
}

const totalGeral = computed(() =>
  fmtValor(
    Object.values(columns)
      .flat()
      .reduce((s, o) => s + Number(o.expected_value || 0), 0)
  )
);

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">
        Funil de vendas
        <span class="text-sm text-n-slate-11 font-normal">· {{ totalGeral }}</span>
        <span v-if="saving" class="text-xs text-n-slate-11">· salvando…</span>
      </h1>
      <button
        class="rounded-lg bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600"
        @click="dialogRef?.open()"
      >
        + Nova oportunidade
      </button>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else class="flex gap-4 overflow-x-auto h-full pb-2">
      <div
        v-for="col in COLUMNS"
        :key="col.key"
        class="flex flex-col w-72 shrink-0 rounded-xl bg-n-alpha-black2 p-3 gap-2 border-t-4"
        :style="{ borderTopColor: col.color }"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold flex items-center gap-2" :style="{ color: col.color }">
            {{ col.label }}
          </span>
          <span class="text-xs text-n-slate-11">{{ totalColuna(col.key) }}</span>
        </div>
        <Draggable
          v-model="columns[col.key]"
          group="pipeline"
          item-key="id"
          class="flex flex-col gap-2 flex-1 min-h-8 overflow-y-auto"
          @change="e => onChange(col.key, e)"
        >
          <template #item="{ element }">
            <div
              class="rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-grab flex flex-col gap-1.5 hover:border-n-slate-7"
              @click="dialogRef?.open(element)"
            >
              <p class="text-sm font-medium text-n-slate-12">{{ element.name }}</p>
              <p class="text-sm text-woot-600 font-semibold">{{ fmtValor(element.expected_value) }}</p>
              <div v-if="element.contact" class="flex items-center gap-1.5">
                <span
                  class="w-5 h-5 rounded grid place-items-center text-white text-[10px] font-semibold"
                  :style="{ backgroundColor: corAvatar(element.contact.name || element.name) }"
                >
                  {{ avatarInicial(element) }}
                </span>
                <span class="text-xs text-n-slate-11 truncate">{{ element.contact.name }}</span>
              </div>
              <div class="flex items-center gap-0.5">
                <span
                  v-for="n in 3"
                  :key="n"
                  class="text-xs"
                  :class="n <= (element.rating || 0) ? 'text-yellow-500' : 'text-n-slate-6'"
                >
                  ★
                </span>
              </div>
            </div>
          </template>
        </Draggable>
      </div>
    </div>

    <OpportunityDialog
      ref="dialogRef"
      :is-loading="saving"
      @save="salvar"
      @ganhar="op => acao(op, 'ganhar')"
      @perder="op => acao(op, 'perder')"
      @move-stage="onMoveStage"
    />
  </div>
</template>
