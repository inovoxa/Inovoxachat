<script setup>
import { ref, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const grupo = ref('Aprovadores GLPI');
const membros = ref([]);
const novoLogin = ref('');
const loading = ref(true);
const busy = ref(false);
const notConfigured = ref(false);
const error = ref('');

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
  if (!novoLogin.value.trim()) return;
  busy.value = true;
  error.value = '';
  try {
    const { data } = await GlpiAPI.addAprovador(novoLogin.value.trim());
    membros.value = data.membros || membros.value;
    novoLogin.value = '';
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
    membros.value = data.membros || membros.value.filter(m => m !== login);
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    busy.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4 max-w-2xl">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">Aprovadores de chamado</h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Membros do grupo do Active Directory <strong>{{ grupo }}</strong>. Alterações refletem no AD.
      </p>
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <div v-else-if="notConfigured" class="text-n-slate-11">
      A integração GLPI ainda não foi configurada para esta empresa.
      <router-link :to="{ name: 'glpi_config' }" class="text-woot-500 underline">
        Configurar agora
      </router-link>
    </div>

    <template v-else>
      <form class="flex gap-2" @submit.prevent="adicionar">
        <input
          v-model="novoLogin"
          type="text"
          placeholder="login do usuário no AD"
          class="flex-1 rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
        />
        <button
          type="submit"
          :disabled="busy"
          class="rounded-lg bg-woot-500 px-4 py-2 text-sm text-white disabled:opacity-60"
        >
          Adicionar
        </button>
      </form>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <ul class="flex flex-col divide-y divide-n-weak/50">
        <li
          v-for="m in membros"
          :key="m"
          class="flex items-center justify-between py-2 text-sm"
        >
          <span class="text-n-slate-12">{{ m }}</span>
          <button
            :disabled="busy"
            class="text-red-500 text-xs hover:underline disabled:opacity-60"
            @click="remover(m)"
          >
            Remover
          </button>
        </li>
        <li v-if="!membros.length" class="py-4 text-center text-n-slate-11">
          Nenhum aprovador cadastrado.
        </li>
      </ul>
    </template>
  </div>
</template>
