<script setup>
import { ref, onMounted } from 'vue';
import ContractsAPI from 'dashboard/api/contracts';
import { useAlert } from 'dashboard/composables';
import ContractCreateDialog from 'dashboard/components-next/Companies/ContractCreateDialog.vue';

const FILTROS = [
  { key: 'a_vencer', label: 'A vencer' },
  { key: 'ativos', label: 'Ativos' },
  { key: 'vencidos', label: 'Vencidos' },
  { key: 'todos', label: 'Todos' },
];
const DIAS_OPTS = [7, 15, 30];
const STATUS = {
  ativo: { label: 'Ativo', cls: 'bg-green-500/15 text-green-600' },
  vencido: { label: 'Vencido', cls: 'bg-red-500/15 text-red-600' },
  encerrado: { label: 'Encerrado', cls: 'bg-slate-500/15 text-slate-500' },
  renovacao_pendente: { label: 'Renovação pendente', cls: 'bg-yellow-500/15 text-yellow-600' },
};

const contratos = ref([]);
const loading = ref(true);
const error = ref('');
const filtro = ref('a_vencer');
const dias = ref(30);
const dialogRef = ref(null);
const saving = ref(false);

async function salvar(payload) {
  saving.value = true;
  try {
    if (payload.id) await ContractsAPI.update(payload.id, { contract: payload });
    else await ContractsAPI.create({ contract: payload });
    dialogRef.value?.onSuccess();
    useAlert('Contrato salvo.');
    load();
  } catch (e) {
    const d = e.response?.data;
    useAlert(d ? [d.error, d.detail].filter(Boolean).join(' — ') : 'Erro ao salvar o contrato.');
  } finally {
    saving.value = false;
  }
}

function fmtData(d) {
  return d ? new Date(d).toLocaleDateString('pt-BR') : '—';
}
function fmtValor(v) {
  return v != null
    ? Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
    : '—';
}
function statusMeta(s) {
  return STATUS[s] || { label: s, cls: 'bg-slate-500/15 text-slate-500' };
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const params = {};
    if (filtro.value === 'a_vencer') {
      params.filter = 'a_vencer';
      params.days = dias.value;
    } else if (filtro.value === 'vencidos') {
      params.filter = 'vencidos';
    } else if (filtro.value === 'ativos') {
      params.filter = 'ativos';
    }
    const { data } = await ContractsAPI.get(params);
    contratos.value = data.payload || [];
  } catch (e) {
    const d = e.response?.data;
    error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
  } finally {
    loading.value = false;
  }
}

function setFiltro(k) {
  filtro.value = k;
  load();
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Contratos</h1>
      <div class="flex items-center gap-2 text-sm">
        <template v-if="filtro === 'a_vencer'">
          <span class="text-n-slate-11">Janela:</span>
          <select
            v-model.number="dias"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-12"
            @change="load"
          >
            <option v-for="d in DIAS_OPTS" :key="d" :value="d">{{ d }} dias</option>
          </select>
        </template>
        <button
          class="rounded-lg bg-woot-500 px-4 py-2 font-medium text-white hover:bg-woot-600"
          @click="dialogRef?.open()"
        >
          + Novo contrato
        </button>
      </div>
    </div>

    <!-- Filtros -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="f in FILTROS"
        :key="f.key"
        class="text-sm px-3 py-1.5 rounded-lg border transition-colors"
        :class="
          filtro === f.key
            ? 'bg-woot-500 border-woot-500 text-white'
            : 'border-n-weak text-n-slate-11 hover:text-n-slate-12'
        "
        @click="setFiltro(f.key)"
      >
        {{ f.label }}
      </button>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div
      v-else-if="!contratos.length"
      class="flex-1 grid place-items-center text-n-slate-11 text-sm"
    >
      Nenhum contrato para este filtro.
    </div>

    <div v-else class="flex-1 overflow-auto rounded-xl border border-n-weak">
      <table class="w-full text-sm">
        <thead class="sticky top-0 bg-n-solid-2">
          <tr class="text-left text-n-slate-11">
            <th class="font-normal px-3 py-2">Empresa</th>
            <th class="font-normal px-3 py-2">Período</th>
            <th class="font-normal px-3 py-2">Vencimento</th>
            <th class="font-normal px-3 py-2">Valor</th>
            <th class="font-normal px-3 py-2">Itens</th>
            <th class="font-normal px-3 py-2">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="c in contratos"
            :key="c.id"
            class="border-t border-n-weak hover:bg-n-alpha-black2 cursor-pointer"
            @click="dialogRef?.open(c)"
          >
            <td class="px-3 py-2 text-n-slate-12">{{ c.company_name || '—' }}</td>
            <td class="px-3 py-2 text-n-slate-11">
              {{ fmtData(c.start_date) }} – {{ fmtData(c.end_date) }}
            </td>
            <td class="px-3 py-2" :class="c.overdue ? 'text-red-500 font-medium' : 'text-n-slate-11'">
              {{ fmtData(c.end_date) }}
            </td>
            <td class="px-3 py-2 text-n-slate-11">{{ fmtValor(c.value) }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ (c.items || []).length }}</td>
            <td class="px-3 py-2">
              <span
                class="text-[11px] px-2 py-0.5 rounded-full font-medium"
                :class="statusMeta(c.status).cls"
              >
                {{ statusMeta(c.status).label }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <ContractCreateDialog ref="dialogRef" :is-loading="saving" @save="salvar" />
  </div>
</template>
