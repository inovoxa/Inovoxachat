<script setup>
import { ref, computed, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const STATUS = {
  synced: { label: 'No AD', cls: 'bg-green-500/15 text-green-600', dot: 'bg-green-500' },
  pending_add: { label: 'A adicionar', cls: 'bg-yellow-500/15 text-yellow-600', dot: 'bg-yellow-500' },
  pending_remove: { label: 'A remover', cls: 'bg-red-500/15 text-red-600', dot: 'bg-red-500' },
};

const grupo = ref('Aprovadores GLPI');
const membros = ref([]);
const novoLogin = ref('');
const novoNome = ref('');
const loading = ref(true);
const busy = ref(false);
const syncing = ref(false);
const importing = ref(false);
const notConfigured = ref(false);
const error = ref('');
const aviso = ref('');

const pendentes = computed(() => membros.value.filter(m => m.status !== 'synced'));
const ordenados = computed(() =>
  [...membros.value].sort((a, b) => (a.nome || a.login).localeCompare(b.nome || b.login))
);

function inicial(m) {
  return (m.nome || m.login || '?').trim().charAt(0).toUpperCase();
}
function corAvatar(login) {
  let h = 0;
  for (let i = 0; i < login.length; i += 1) h = (h * 31 + login.charCodeAt(i)) % 360;
  return `hsl(${h}, 55%, 45%)`;
}

async function load() {
  loading.value = true;
  error.value = '';
  notConfigured.value = false;
  try {
    const { data } = await GlpiAPI.getAprovadores();
    grupo.value = data.grupo || grupo.value;
    membros.value = data.membros || [];
  } catch (e) {
    if (e.response?.status === 404) notConfigured.value = true;
    else error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

async function adicionar() {
  const login = novoLogin.value.trim();
  if (!login) return;
  busy.value = true;
  error.value = '';
  aviso.value = '';
  try {
    const { data } = await GlpiAPI.addAprovador(login, novoNome.value.trim() || undefined);
    membros.value = data.membros || membros.value;
    novoLogin.value = '';
    novoNome.value = '';
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    busy.value = false;
  }
}

async function remover(login) {
  busy.value = true;
  error.value = '';
  try {
    const { data } = await GlpiAPI.removeAprovador(login);
    membros.value = data.membros || membros.value;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    busy.value = false;
  }
}

async function sincronizar() {
  syncing.value = true;
  error.value = '';
  aviso.value = '';
  try {
    const { data } = await GlpiAPI.syncAprovadores();
    membros.value = data.membros || membros.value;
    const falhas = (data.resultados || []).filter(r => !r.ok);
    aviso.value = falhas.length
      ? `Sincronizado com ${falhas.length} falha(s): ${falhas.map(f => `${f.login} (${f.erro})`).join('; ')}`
      : 'Sincronizado com o AD com sucesso.';
  } catch (e) {
    const d = e.response?.data;
    error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
  } finally {
    syncing.value = false;
  }
}

async function importar() {
  importing.value = true;
  error.value = '';
  aviso.value = '';
  try {
    const { data } = await GlpiAPI.importAprovadores();
    membros.value = data.membros || membros.value;
    aviso.value = 'Membros do AD importados.';
  } catch (e) {
    const d = e.response?.data;
    error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
  } finally {
    importing.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-5 max-w-5xl">
    <div class="flex items-start justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">Aprovadores de chamado</h1>
        <p class="text-sm text-n-slate-11 mt-1">
          A lista fica salva aqui no Inovoxachat. As alterações só vão para o grupo
          <strong>{{ grupo }}</strong> do AD quando você clicar em <strong>Sincronizar</strong>.
        </p>
      </div>
      <button
        :disabled="syncing || !pendentes.length"
        class="rounded-lg bg-woot-500 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-woot-600 disabled:opacity-50 flex items-center gap-2"
        @click="sincronizar"
      >
        <span v-if="syncing">Sincronizando…</span>
        <span v-else>Sincronizar com o AD</span>
        <span
          v-if="pendentes.length"
          class="bg-white/25 rounded-full px-1.5 text-xs"
        >{{ pendentes.length }}</span>
      </button>
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">Configurar agora</router-link>
    </div>

    <template v-else>
      <!-- Banner de pendências -->
      <div
        v-if="pendentes.length"
        class="rounded-xl border border-yellow-500/40 bg-yellow-500/10 px-4 py-2.5 text-sm text-yellow-700 flex items-center gap-2"
      >
        <span>⚠</span>
        <span>
          {{ pendentes.length }} alteração(ões) pendente(s) — ainda não aplicada(s) no AD.
          Clique em <strong>Sincronizar</strong> para confirmar.
        </span>
      </div>

      <!-- Adicionar -->
      <form class="flex gap-2 flex-wrap items-end" @submit.prevent="adicionar">
        <label class="flex flex-col gap-1 flex-1 min-w-44">
          <span class="text-xs text-n-slate-11">Login no AD</span>
          <input
            v-model="novoLogin"
            type="text"
            placeholder="ex.: pma\\joao.silva"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
          />
        </label>
        <label class="flex flex-col gap-1 flex-1 min-w-44">
          <span class="text-xs text-n-slate-11">Nome (opcional)</span>
          <input
            v-model="novoNome"
            type="text"
            placeholder="ex.: João Silva"
            class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
          />
        </label>
        <button
          type="submit"
          :disabled="busy || !novoLogin.trim()"
          class="rounded-lg bg-n-solid-3 border border-n-weak px-4 py-2 text-sm text-n-slate-12 hover:border-n-slate-7 disabled:opacity-50"
        >
          + Adicionar
        </button>
        <button
          type="button"
          :disabled="importing"
          class="rounded-lg px-4 py-2 text-sm text-n-slate-11 hover:text-n-slate-12 disabled:opacity-50"
          title="Puxa os membros atuais do grupo no AD para esta lista"
          @click="importar"
        >
          {{ importing ? 'Importando…' : 'Importar do AD' }}
        </button>
      </form>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
      <p v-if="aviso" class="text-green-600 text-sm">{{ aviso }}</p>

      <!-- Cards -->
      <div
        v-if="ordenados.length"
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3"
      >
        <div
          v-for="m in ordenados"
          :key="m.login"
          class="group relative rounded-xl border border-n-weak bg-n-alpha-black2 p-4 flex items-center gap-3 hover:border-n-slate-7 transition-colors"
          :class="{ 'opacity-70': m.status === 'pending_remove' }"
        >
          <div
            class="w-11 h-11 rounded-full grid place-items-center text-white font-semibold shrink-0"
            :style="{ backgroundColor: corAvatar(m.login) }"
          >
            {{ inicial(m) }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-n-slate-12 truncate">{{ m.nome || m.login }}</p>
            <p v-if="m.nome" class="text-xs text-n-slate-11 truncate">{{ m.login }}</p>
            <span
              class="mt-1 inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded-full font-medium"
              :class="STATUS[m.status].cls"
            >
              <span class="w-1.5 h-1.5 rounded-full" :class="STATUS[m.status].dot" />
              {{ STATUS[m.status].label }}
            </span>
          </div>
          <button
            :disabled="busy"
            class="absolute top-2 right-2 w-6 h-6 grid place-items-center rounded-full text-n-slate-11 hover:bg-red-500/15 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity disabled:opacity-50"
            title="Remover"
            @click="remover(m.login)"
          >
            ✕
          </button>
        </div>
      </div>

      <!-- Estado vazio -->
      <div
        v-else
        class="rounded-xl border border-dashed border-n-weak py-12 grid place-items-center text-center gap-1"
      >
        <span class="text-3xl">👥</span>
        <p class="text-sm text-n-slate-12">Nenhum aprovador cadastrado.</p>
        <p class="text-xs text-n-slate-11">
          Adicione pelo login acima ou clique em <strong>Importar do AD</strong>.
        </p>
      </div>
    </template>
  </div>
</template>
