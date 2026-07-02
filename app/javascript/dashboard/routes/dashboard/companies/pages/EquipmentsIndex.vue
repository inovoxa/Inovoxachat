<script setup>
import { ref, onMounted } from 'vue';
import EquipmentsAPI from 'dashboard/api/equipments';

const FILTROS = [
  { key: '', label: 'Todos' },
  { key: 'alugado', label: 'Alugados' },
  { key: 'disponivel', label: 'Disponíveis' },
  { key: 'manutencao', label: 'Em manutenção' },
];
const STATUS = {
  disponivel: { label: 'Disponível', cls: 'bg-green-500/15 text-green-600' },
  alugado: { label: 'Alugado', cls: 'bg-blue-500/15 text-blue-600' },
  manutencao: { label: 'Em manutenção', cls: 'bg-yellow-500/15 text-yellow-600' },
};

const equipamentos = ref([]);
const loading = ref(true);
const error = ref('');
const filtro = ref('');

function statusMeta(s) {
  return STATUS[s] || { label: s, cls: 'bg-slate-500/15 text-slate-500' };
}

async function load() {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await EquipmentsAPI.get(filtro.value ? { status: filtro.value } : {});
    equipamentos.value = data.payload || [];
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
    <h1 class="text-xl font-medium text-n-slate-12">Equipamentos</h1>

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
      v-else-if="!equipamentos.length"
      class="flex-1 grid place-items-center text-n-slate-11 text-sm"
    >
      Nenhum equipamento encontrado.
    </div>

    <div v-else class="flex-1 overflow-auto rounded-xl border border-n-weak">
      <table class="w-full text-sm">
        <thead class="sticky top-0 bg-n-solid-2">
          <tr class="text-left text-n-slate-11">
            <th class="font-normal px-3 py-2">Equipamento</th>
            <th class="font-normal px-3 py-2">Nº de série</th>
            <th class="font-normal px-3 py-2">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="e in equipamentos"
            :key="e.id"
            class="border-t border-n-weak hover:bg-n-alpha-black2"
          >
            <td class="px-3 py-2 text-n-slate-12">{{ e.name }}</td>
            <td class="px-3 py-2 text-n-slate-11">{{ e.serial || '—' }}</td>
            <td class="px-3 py-2">
              <span
                class="text-[11px] px-2 py-0.5 rounded-full font-medium"
                :class="statusMeta(e.status).cls"
              >
                {{ statusMeta(e.status).label }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
