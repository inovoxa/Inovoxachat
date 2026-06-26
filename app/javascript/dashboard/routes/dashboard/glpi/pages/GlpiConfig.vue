<script setup>
import { ref, reactive, onMounted } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const GROUPS = [
  {
    title: 'GLPI — Banco (MySQL) e API',
    fields: [
      { key: 'GLPI_DB_HOST', label: 'Host do banco GLPI' },
      { key: 'GLPI_DB_PORT', label: 'Porta' },
      { key: 'GLPI_DB_USER', label: 'Usuário' },
      { key: 'GLPI_DB_DATABASE', label: 'Database' },
      { key: 'GLPI_API_V1_URL', label: 'URL da API v1' },
    ],
  },
  {
    title: 'PostgreSQL (n8n)',
    fields: [
      { key: 'PG_HOST', label: 'Host' },
      { key: 'PG_PORT', label: 'Porta' },
      { key: 'PG_USER', label: 'Usuário' },
      { key: 'PG_DATABASE', label: 'Database' },
      { key: 'PG_SCHEMA', label: 'Schema' },
    ],
  },
  {
    title: 'Active Directory (SSH)',
    fields: [
      { key: 'AD_SSH_HOST', label: 'Host SSH' },
      { key: 'AD_SSH_PORT', label: 'Porta SSH' },
      { key: 'AD_SSH_USER', label: 'Usuário SSH' },
      { key: 'AD_SCRIPT_PATH', label: 'Script de auditoria' },
      { key: 'AD_APROVADORES_SCRIPT', label: 'Script de aprovadores' },
      { key: 'AD_COLLECTOR_CRON', label: 'Cron do coletor' },
    ],
  },
  {
    title: 'Agente IA (ROI)',
    fields: [
      { key: 'AGENTE_MIN_POR_OP', label: 'Minutos por operação' },
      { key: 'AGENTE_CUSTO_HORA', label: 'Custo por hora (R$)' },
    ],
  },
];

const SECRETS = [
  { key: 'GLPI_DB_PASSWORD', label: 'Senha do banco GLPI' },
  { key: 'PG_PASSWORD', label: 'Senha do PostgreSQL' },
  { key: 'AD_SSH_PASSWORD', label: 'Senha do AD (SSH)' },
];

const enabled = ref(false);
const settings = reactive({});
const secretsInput = reactive({});
const secretsPresent = reactive({});
const loading = ref(true);
const saving = ref(false);
const message = ref('');
const isError = ref(false);

async function load() {
  loading.value = true;
  try {
    const { data } = await GlpiAPI.getConfig();
    enabled.value = data.enabled;
    Object.assign(settings, data.settings || {});
    Object.assign(secretsPresent, data.secrets_present || {});
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
    const secrets = {};
    SECRETS.forEach(s => {
      if (secretsInput[s.key]) secrets[s.key] = secretsInput[s.key];
    });
    const { data } = await GlpiAPI.updateConfig({
      settings: { ...settings },
      secrets,
    });
    enabled.value = data.enabled;
    Object.assign(secretsPresent, data.secrets_present || {});
    SECRETS.forEach(s => {
      secretsInput[s.key] = '';
    });
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
  <div class="flex flex-col w-full h-full overflow-auto p-6 gap-5 max-w-3xl">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">Integração GLPI</h1>
      <p class="text-sm text-n-slate-11 mt-1">
        Variáveis de conexão desta empresa. O Chatwoot acessa diretamente o GLPI, o PostgreSQL e o
        Active Directory configurados aqui. Os dados são exclusivos desta empresa.
      </p>
    </div>

    <p v-if="loading" class="text-n-slate-11">Carregando…</p>

    <form v-else class="flex flex-col gap-6" @submit.prevent="save">
      <div class="text-sm text-n-slate-12 rounded-lg bg-n-alpha-black2 px-3 py-2">
        Status do módulo:
        <strong>{{ enabled ? 'Habilitado' : 'Desabilitado' }}</strong>
        <span class="text-n-slate-11">— controlado pelo super administrador.</span>
      </div>

      <div v-for="group in GROUPS" :key="group.title" class="flex flex-col gap-3">
        <h2 class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-1">
          {{ group.title }}
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label v-for="f in group.fields" :key="f.key" class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">{{ f.label }}</span>
            <input
              v-model="settings[f.key]"
              type="text"
              class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
        </div>
      </div>

      <div class="flex flex-col gap-3">
        <h2 class="text-sm font-semibold text-n-slate-12 border-b border-n-weak pb-1">
          Senhas (guardadas cifradas)
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label v-for="s in SECRETS" :key="s.key" class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">{{ s.label }}</span>
            <input
              v-model="secretsInput[s.key]"
              type="password"
              autocomplete="new-password"
              :placeholder="secretsPresent[s.key] ? '•••••••• (definida — deixe em branco para manter)' : 'definir senha'"
              class="rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
        </div>
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
