<script setup>
import { reactive, ref, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import RepairOrdersAPI from 'dashboard/api/repairOrders';
import { useAlert } from 'dashboard/composables';
import RepairDialog from '../components/RepairDialog.vue';

const COLUMNS = [
  { key: 'novo', label: 'Novo', color: '#5B7FDE' },
  { key: 'confirmado', label: 'Confirmado', color: '#a06bff' },
  { key: 'em_reparo', label: 'Em reparo', color: '#FFB454' },
  { key: 'reparado', label: 'Reparado', color: '#3ddc97' },
];

const columns = reactive({});
COLUMNS.forEach(c => {
  columns[c.key] = [];
});
const loading = ref(true);
const saving = ref(false);
const error = ref('');
const dialogRef = ref(null);

function fmtDataHora(d) {
  return d ? new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '';
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await RepairOrdersAPI.get();
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
  saving.value = true;
  try {
    await RepairOrdersAPI.move(evt.added.element.id, stage, evt.added.newIndex);
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao mover a ordem.');
    load();
  } finally {
    saving.value = false;
  }
}

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await RepairOrdersAPI.update(payload.id, { repair_order: payload });
    else await RepairOrdersAPI.create({ repair_order: payload });
    dialogRef.value?.onSuccess();
    useAlert('Ordem de reparo salva.');
    load();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao salvar a ordem.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3">
      <h1 class="text-xl font-medium text-n-slate-12">
        Ordens de reparo
        <span v-if="saving" class="text-xs text-n-slate-11">· salvando…</span>
      </h1>
      <button
        class="rounded-lg bg-woot-500 px-4 py-2 text-sm font-medium text-white hover:bg-woot-600"
        @click="dialogRef?.open()"
      >
        + Nova ordem
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
          <span class="text-sm font-semibold" :style="{ color: col.color }">{{ col.label }}</span>
          <span class="text-xs text-n-slate-11">{{ columns[col.key].length }}</span>
        </div>
        <Draggable
          v-model="columns[col.key]"
          group="repairs"
          item-key="id"
          class="flex flex-col gap-2 flex-1 min-h-8 overflow-y-auto"
          @change="e => onChange(col.key, e)"
        >
          <template #item="{ element }">
            <div
              class="rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-grab flex flex-col gap-1"
              @click="dialogRef?.open(element)"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs text-n-slate-11">{{ element.codigo }}</span>
                <span
                  v-if="element.in_warranty"
                  class="text-[10px] px-1.5 py-0.5 rounded-full bg-green-500/15 text-green-600 font-medium"
                >
                  Garantia
                </span>
              </div>
              <p class="text-sm text-n-slate-12">
                {{ element.product_name || element.equipment_name || 'Sem produto' }}
              </p>
              <p v-if="element.company_name" class="text-xs text-n-slate-11">{{ element.company_name }}</p>
              <p v-if="element.scheduled_at" class="text-xs text-n-slate-11">
                🕐 {{ fmtDataHora(element.scheduled_at) }}
              </p>
              <p v-if="element.assignee" class="text-xs text-n-slate-11">{{ element.assignee.name }}</p>
            </div>
          </template>
        </Draggable>
      </div>
    </div>

    <RepairDialog ref="dialogRef" :is-loading="saving" @save="salvar" />
  </div>
</template>
