<script setup>
import { reactive, ref, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import ProjectsAPI from 'dashboard/api/projects';
import ProjectTasksAPI from 'dashboard/api/projectTasks';
import AgentAPI from 'dashboard/api/agents';
import { useAlert } from 'dashboard/composables';

const COLUMNS = [
  { key: 'inicio', label: 'Início', color: '#5B7FDE' },
  { key: 'em_andamento', label: 'Em andamento', color: '#FFB454' },
  { key: 'concluido', label: 'Concluído', color: '#3ddc97' },
];

const projetos = ref([]);
const agentes = ref([]);
const projetoAtual = ref('');
const columns = reactive({});
COLUMNS.forEach(c => {
  columns[c.key] = [];
});
const novoProjeto = ref('');
const novaTarefa = reactive({});
COLUMNS.forEach(c => {
  novaTarefa[c.key] = '';
});
const loading = ref(true);
const saving = ref(false);
const error = ref('');

function nomeAgente(id) {
  const a = agentes.value.find(x => String(x.id) === String(id));
  return a ? a.available_name || a.name : '';
}
function inicial(txt) {
  return (txt || '?').trim().charAt(0).toUpperCase();
}

async function carregarProjetos() {
  try {
    const { data } = await ProjectsAPI.get();
    projetos.value = data.payload || [];
    if (!projetoAtual.value && projetos.value.length) projetoAtual.value = projetos.value[0].id;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  }
}

async function carregarTarefas() {
  COLUMNS.forEach(c => {
    columns[c.key] = [];
  });
  if (!projetoAtual.value) return;
  const { data } = await ProjectTasksAPI.get({ project_id: projetoAtual.value });
  (data.payload || []).forEach(t => {
    (columns[t.stage] || columns.inicio).push(t);
  });
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    try {
      const { data } = await AgentAPI.get();
      agentes.value = data || [];
    } catch (e) {
      agentes.value = [];
    }
    await carregarProjetos();
    await carregarTarefas();
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

async function trocarProjeto() {
  loading.value = true;
  await carregarTarefas();
  loading.value = false;
}

async function criarProjeto() {
  const name = novoProjeto.value.trim();
  if (!name) return;
  saving.value = true;
  try {
    const { data } = await ProjectsAPI.create({ project: { name } });
    novoProjeto.value = '';
    await carregarProjetos();
    projetoAtual.value = data.payload.id;
    await carregarTarefas();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao criar projeto.');
  } finally {
    saving.value = false;
  }
}

async function criarTarefa(stage) {
  const title = novaTarefa[stage].trim();
  if (!title || !projetoAtual.value) return;
  saving.value = true;
  try {
    const { data } = await ProjectTasksAPI.create({
      project_task: { project_id: projetoAtual.value, title, stage },
    });
    columns[stage].push(data.payload);
    novaTarefa[stage] = '';
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao criar tarefa.');
  } finally {
    saving.value = false;
  }
}

async function onChange(stage, evt) {
  if (!evt.added) return;
  const card = evt.added.element;
  saving.value = true;
  try {
    await ProjectTasksAPI.move(card.id, stage, evt.added.newIndex);
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao mover.');
    carregarTarefas();
  } finally {
    saving.value = false;
  }
}

async function remover(stage, task) {
  saving.value = true;
  try {
    await ProjectTasksAPI.delete(task.id);
    columns[stage] = columns[stage].filter(t => t.id !== task.id);
  } catch (e) {
    useAlert('Erro ao remover a tarefa.');
  } finally {
    saving.value = false;
  }
}

async function atribuir(task, assigneeId) {
  try {
    await ProjectTasksAPI.update(task.id, { project_task: { assignee_id: assigneeId || null } });
    task.assignee_id = assigneeId;
  } catch (e) {
    useAlert('Erro ao atribuir responsável.');
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-3">
        <h1 class="text-xl font-medium text-n-slate-12">Projetos</h1>
        <select
          v-if="projetos.length"
          v-model="projetoAtual"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
          @change="trocarProjeto"
        >
          <option v-for="p in projetos" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
        <span v-if="saving" class="text-xs text-n-slate-11">salvando…</span>
      </div>
      <form class="flex items-center gap-2" @submit.prevent="criarProjeto">
        <input
          v-model="novoProjeto"
          type="text"
          placeholder="Novo projeto…"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-48"
        />
        <button
          type="submit"
          :disabled="!novoProjeto.trim()"
          class="rounded-lg bg-woot-500 px-3 py-1.5 text-sm text-white disabled:opacity-50"
        >
          + Projeto
        </button>
      </form>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div
      v-else-if="!projetos.length"
      class="flex-1 grid place-items-center text-n-slate-11 text-sm"
    >
      Nenhum projeto ainda. Crie o primeiro acima.
    </div>

    <div v-else class="flex gap-4 overflow-x-auto h-full pb-2">
      <div
        v-for="col in COLUMNS"
        :key="col.key"
        class="flex flex-col w-80 shrink-0 rounded-xl bg-n-alpha-black2 p-3 gap-2 border-t-4"
        :style="{ borderTopColor: col.color }"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold" :style="{ color: col.color }">{{ col.label }}</span>
          <span class="text-xs text-n-slate-11">{{ columns[col.key].length }}</span>
        </div>
        <Draggable
          v-model="columns[col.key]"
          group="tasks"
          item-key="id"
          class="flex flex-col gap-2 flex-1 min-h-8 overflow-y-auto"
          @change="e => onChange(col.key, e)"
        >
          <template #item="{ element }">
            <div class="group rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-grab flex flex-col gap-2">
              <div class="flex items-start justify-between gap-2">
                <p class="text-sm text-n-slate-12">{{ element.title }}</p>
                <button
                  class="text-n-slate-11 hover:text-red-600 opacity-0 group-hover:opacity-100 text-xs"
                  @click="remover(col.key, element)"
                >
                  ✕
                </button>
              </div>
              <div class="flex items-center gap-2">
                <span
                  v-if="element.assignee_id"
                  class="w-5 h-5 rounded-full grid place-items-center bg-woot-500 text-white text-[10px] font-semibold"
                >
                  {{ inicial(nomeAgente(element.assignee_id)) }}
                </span>
                <select
                  :value="element.assignee_id || ''"
                  class="text-xs rounded border border-n-weak bg-n-alpha-black2 px-1 py-0.5 text-n-slate-11"
                  @change="e => atribuir(element, e.target.value)"
                  @click.stop
                >
                  <option value="">Sem responsável</option>
                  <option v-for="a in agentes" :key="a.id" :value="a.id">
                    {{ a.available_name || a.name }}
                  </option>
                </select>
              </div>
            </div>
          </template>
        </Draggable>
        <input
          v-model="novaTarefa[col.key]"
          type="text"
          placeholder="+ nova tarefa"
          class="text-sm rounded-lg border border-n-weak bg-n-solid-2 px-2 py-1.5 text-n-slate-12"
          @keyup.enter="criarTarefa(col.key)"
        />
      </div>
    </div>
  </div>
</template>
