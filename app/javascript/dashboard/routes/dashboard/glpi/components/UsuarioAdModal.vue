<script setup>
import { ref, watch, computed } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const props = defineProps({
  login: { type: String, default: '' },
});
const emit = defineEmits(['close']);

const usuario = ref(null);
const loading = ref(false);
const error = ref('');

function fmtData(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString('pt-BR');
}

const campos = computed(() => {
  const u = usuario.value || {};
  return [
    { label: 'E-mail', valor: u.email },
    { label: 'Mobile', valor: u.mobile },
    { label: 'Departamento', valor: u.departamento },
    { label: 'Cargo', valor: u.cargo },
    { label: 'Organization', valor: u.organization },
    { label: 'Escritório', valor: u.escritorio },
    { label: 'Logon script', valor: u.logon_script },
    { label: 'Criado em', valor: fmtData(u.data_criacao) },
    { label: 'Último logon', valor: fmtData(u.ultimo_logon_ad) },
    { label: 'Troca de senha', valor: fmtData(u.ultima_troca_senha) },
    { label: 'Última senha incorreta', valor: fmtData(u.ultima_senha_incorreta) },
    { label: 'Logins sem sucesso', valor: u.logins_sem_sucesso ?? '—' },
  ].filter(c => c.valor && c.valor !== '—' || c.label === 'Logins sem sucesso');
});

watch(
  () => props.login,
  async login => {
    if (!login) {
      usuario.value = null;
      return;
    }
    usuario.value = null;
    error.value = '';
    loading.value = true;
    try {
      const { data } = await GlpiAPI.getUsuarioAd(login);
      usuario.value = data.usuario;
    } catch (e) {
      const d = e.response?.data;
      error.value = d ? [d.error, d.detail].filter(Boolean).join(' — ') : e.message;
    } finally {
      loading.value = false;
    }
  },
  { immediate: true }
);
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="bg-n-solid-1 rounded-2xl w-full max-w-2xl max-h-[85vh] overflow-auto p-6 flex flex-col gap-4 border border-n-weak"
    >
      <div class="flex items-start justify-between">
        <h2 class="text-lg font-medium text-n-slate-12">
          Usuário AD<span v-if="login"> · {{ login }}</span>
        </h2>
        <button class="text-n-slate-11 hover:text-n-slate-12" @click="emit('close')">✕</button>
      </div>

      <p v-if="loading" class="text-n-slate-11">Consultando o AD…</p>
      <p v-else-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <template v-else-if="usuario">
        <!-- Cabeçalho: nome + status -->
        <div class="flex items-center gap-3 flex-wrap">
          <p class="text-base font-medium text-n-slate-12">{{ usuario.nome || usuario.login }}</p>
          <span
            class="text-xs px-2 py-0.5 rounded-full font-medium"
            :class="usuario.habilitado ? 'bg-green-500/15 text-green-600' : 'bg-red-500/15 text-red-600'"
          >
            {{ usuario.habilitado ? 'Ativo' : 'Desativado' }}
          </span>
          <span
            v-if="usuario.bloqueado"
            class="text-xs px-2 py-0.5 rounded-full font-medium bg-red-500/15 text-red-600"
          >
            Bloqueado
          </span>
        </div>

        <!-- Campos -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
          <p v-for="c in campos" :key="c.label">
            <span class="text-n-slate-11">{{ c.label }}:</span> {{ c.valor }}
          </p>
        </div>

        <!-- Árvore / OU -->
        <div v-if="usuario.arvore || usuario.dn">
          <p class="text-sm font-medium text-n-slate-12 mb-1 border-b border-n-weak pb-1">Árvore / OU</p>
          <p class="text-xs text-n-slate-11 break-all mt-1">{{ usuario.arvore || usuario.dn }}</p>
        </div>

        <!-- Grupos -->
        <div v-if="(usuario.grupos || []).length">
          <p class="text-sm font-medium text-n-slate-12 mb-2 border-b border-n-weak pb-1">
            Grupos ({{ usuario.grupos.length }})
          </p>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="g in usuario.grupos"
              :key="g"
              class="text-xs px-2 py-0.5 rounded-full bg-n-alpha-black2 text-n-slate-12 border border-n-weak"
            >
              {{ g }}
            </span>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
