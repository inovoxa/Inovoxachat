<script setup>
import { ref, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const enabled = ref(false);
const centralUrl = ref('');
const serviceToken = ref('');
const hasToken = ref(false);
const loading = ref(true);
const saving = ref(false);
const message = ref('');
const isError = ref(false);

async function load() {
  loading.value = true;
  try {
    const { data } = await GlpiAPI.getConfig();
    enabled.value = data.enabled;
    centralUrl.value = data.central_url || '';
    hasToken.value = data.has_token;
  } catch (e) {
    isError.value = true;
    message.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
}

async function save() {
  saving.value = true;
  message.value = '';
  isError.value = false;
  try {
    const payload = { enabled: enabled.value, central_url: centralUrl.value };
    if (serviceToken.value) payload.service_token = serviceToken.value;
    const { data } = await GlpiAPI.updateConfig(payload);
    hasToken.value = data.has_token;
    serviceToken.value = '';
    message.value = 'Configuração salva com sucesso.';
  } catch (e) {
    isError.value = true;
    message.value = e.response?.data?.error || e.message;
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-4 max-w-2xl">
    <h1 class="text-xl font-medium text-n-slate-12">Integração GLPI</h1>
    <p class="text-sm text-n-slate-11">
      Conecte esta empresa à sua Central de Operações GLPI. Os dados (chamados, kanban, agente)
      são exclusivos desta empresa.
    </p>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <form v-else class="flex flex-col gap-4" @submit.prevent="save">
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="enabled" type="checkbox" />
        Integração habilitada
      </label>

      <div class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">URL da Central</span>
        <input
          v-model="centralUrl"
          type="url"
          placeholder="https://central.suaempresa.com.br"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
        />
      </div>

      <div class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">Token de serviço</span>
        <input
          v-model="serviceToken"
          type="password"
          :placeholder="hasToken ? '•••••••• (deixe em branco para manter)' : 'cole o token de serviço'"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
        />
        <span class="text-xs text-n-slate-11">
          Deve ser igual ao CENTRAL_SERVICE_TOKEN configurado na Central desta empresa.
        </span>
      </div>

      <div class="flex items-center gap-3">
        <button
          type="submit"
          :disabled="saving"
          class="rounded-lg bg-woot-500 px-4 py-2 text-sm text-white disabled:opacity-60"
        >
          {{ saving ? 'Salvando…' : 'Salvar' }}
        </button>
        <span v-if="message" :class="isError ? 'text-red-500' : 'text-green-600'" class="text-sm">
          {{ message }}
        </span>
      </div>
    </form>
  </div>
</template>
