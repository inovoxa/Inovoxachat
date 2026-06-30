<script setup>
import { ref, computed, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';
import InventarioDetailModal from '../components/InventarioDetailModal.vue';

const itens = ref([]);
const total = ref(0);
const page = ref(1);
const perPage = ref(10);
const search = ref('');
const os = ref('');
const loading = ref(true);
const notConfigured = ref(false);
const error = ref('');
const selectedId = ref(null);
let searchTimer = null;

const PER_PAGE_OPTS = [10, 25, 50];

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / perPage.value)));
const inicio = computed(() => (total.value === 0 ? 0 : (page.value - 1) * perPage.value + 1));
const fim = computed(() => Math.min(page.value * perPage.value, total.value));

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getInventario({
      page: page.value,
      per_page: perPage.value,
      search: search.value || undefined,
      os: os.value || undefined,
    });
    itens.value = data.itens || [];
    total.value = data.total || 0;
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else {
      const d = e.response?.data;
      error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
    }
  } finally {
    loading.value = false;
  }
}

function reload() {
  page.value = 1;
  load();
}

function onSearch() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(reload, 400);
}

function changePerPage() {
  page.value = 1;
  load();
}

function goto(p) {
  if (p < 1 || p > totalPages.value) return;
  page.value = p;
  load();
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <h1 class="text-xl font-medium text-n-slate-12">Inventário (OCS)</h1>
      <div class="flex items-center gap-2 flex-wrap">
        <input
          v-model="search"
          type="search"
          placeholder="Buscar nome, usuário, IP, SO ou nº de série"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-72"
          @input="onSearch"
        />
        <input
          v-model="os"
          type="search"
          placeholder="Filtrar SO"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12 w-36"
          @input="onSearch"
        />
      </div>
    </div>

    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI/OCS ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">Configurar agora</router-link>
    </div>

    <div v-else-if="!itens.length" class="flex-1 grid place-items-center text-n-slate-11 text-sm">
      Nenhuma máquina encontrada.
    </div>

    <template v-else>
      <div class="flex-1 overflow-auto rounded-xl border border-n-weak">
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-n-solid-2">
            <tr class="text-left text-n-slate-11">
              <th class="font-normal px-3 py-2">Máquina</th>
              <th class="font-normal px-3 py-2">Usuário</th>
              <th class="font-normal px-3 py-2">SO</th>
              <th class="font-normal px-3 py-2">IP</th>
              <th class="font-normal px-3 py-2">Equipamento</th>
              <th class="font-normal px-3 py-2">Último contato</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="m in itens"
              :key="m.id"
              class="border-t border-n-weak hover:bg-n-alpha-black2 cursor-pointer"
              @click="selectedId = m.id"
            >
              <td class="px-3 py-2 text-n-slate-12">{{ m.nome }}</td>
              <td class="px-3 py-2 text-n-slate-11">{{ m.usuario || '—' }}</td>
              <td class="px-3 py-2 text-n-slate-11">{{ m.so || '—' }}</td>
              <td class="px-3 py-2 text-n-slate-11">{{ m.ip || '—' }}</td>
              <td class="px-3 py-2 text-n-slate-11">
                {{ [m.fabricante, m.modelo].filter(Boolean).join(' ') || '—' }}
              </td>
              <td class="px-3 py-2 text-n-slate-11">{{ m.ultimoContato || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Paginação -->
      <div class="flex items-center justify-between gap-3 flex-wrap text-sm">
        <div class="flex items-center gap-2 text-n-slate-11">
          <span>Por página:</span>
          <select
            v-model.number="perPage"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1 text-n-slate-12"
            @change="changePerPage"
          >
            <option v-for="o in PER_PAGE_OPTS" :key="o" :value="o">{{ o }}</option>
          </select>
          <span>{{ inicio }}–{{ fim }} de {{ total }}</span>
        </div>
        <div class="flex items-center gap-2">
          <button
            class="rounded-lg border border-n-weak px-3 py-1 text-n-slate-12 disabled:opacity-40"
            :disabled="page <= 1"
            @click="goto(page - 1)"
          >
            Anterior
          </button>
          <span class="text-n-slate-11">{{ page }} / {{ totalPages }}</span>
          <button
            class="rounded-lg border border-n-weak px-3 py-1 text-n-slate-12 disabled:opacity-40"
            :disabled="page >= totalPages"
            @click="goto(page + 1)"
          >
            Próxima
          </button>
        </div>
      </div>
    </template>

    <InventarioDetailModal v-if="selectedId" :machine-id="selectedId" @close="selectedId = null" />
  </div>
</template>
