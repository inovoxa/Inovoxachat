<script setup>
import { ref, watch } from 'vue';
import GlpiAPI from 'dashboard/api/glpi';

const props = defineProps({
  machineId: { type: [Number, String], default: null },
});
const emit = defineEmits(['close']);

const detail = ref(null);
const loading = ref(false);
const error = ref('');

function gb(mb) {
  const n = Number(mb);
  if (!n) return '—';
  return n >= 1024 ? `${(n / 1024).toFixed(1).replace('.', ',')} GB` : `${n} MB`;
}

watch(
  () => props.machineId,
  async id => {
    if (!id) {
      detail.value = null;
      return;
    }
    detail.value = null;
    error.value = '';
    loading.value = true;
    try {
      const { data } = await GlpiAPI.getInventarioItem(id);
      detail.value = data;
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
      class="bg-n-solid-1 rounded-2xl w-full max-w-3xl max-h-[85vh] overflow-auto p-6 flex flex-col gap-5 border border-n-weak"
    >
      <div class="flex items-start justify-between">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ detail ? detail.hardware.nome : 'Máquina' }}
        </h2>
        <button class="text-n-slate-11 hover:text-n-slate-12" @click="emit('close')">✕</button>
      </div>

      <p v-if="loading" class="text-n-slate-11">Carregando…</p>
      <p v-else-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <template v-else-if="detail">
        <!-- Hardware -->
        <div class="grid grid-cols-2 md:grid-cols-3 gap-2 text-sm">
          <p><span class="text-n-slate-11">Usuário:</span> {{ detail.hardware.usuario || '—' }}</p>
          <p><span class="text-n-slate-11">Domínio:</span> {{ detail.hardware.dominio || '—' }}</p>
          <p><span class="text-n-slate-11">SO:</span> {{ detail.hardware.so || '—' }}</p>
          <p><span class="text-n-slate-11">Versão SO:</span> {{ detail.hardware.soVersao || '—' }}</p>
          <p><span class="text-n-slate-11">Arquitetura:</span> {{ detail.hardware.arquitetura || '—' }}</p>
          <p><span class="text-n-slate-11">IP:</span> {{ detail.hardware.ip || '—' }}</p>
          <p><span class="text-n-slate-11">Processador:</span> {{ detail.hardware.processador || '—' }}</p>
          <p><span class="text-n-slate-11">Memória:</span> {{ gb(detail.hardware.memoriaMb) }}</p>
          <p><span class="text-n-slate-11">Último contato:</span> {{ detail.hardware.ultimoContato || '—' }}</p>
        </div>

        <!-- BIOS / Serial -->
        <div>
          <p class="text-sm font-medium text-n-slate-12 mb-1 border-b border-n-weak pb-1">Equipamento</p>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-2 text-sm mt-2">
            <p><span class="text-n-slate-11">Fabricante:</span> {{ detail.bios.fabricante || '—' }}</p>
            <p><span class="text-n-slate-11">Modelo:</span> {{ detail.bios.modelo || '—' }}</p>
            <p><span class="text-n-slate-11">Nº de série:</span> {{ detail.bios.serial || '—' }}</p>
            <p><span class="text-n-slate-11">BIOS:</span> {{ detail.bios.biosVersao || '—' }}</p>
          </div>
        </div>

        <!-- Rede -->
        <div v-if="detail.redes.length">
          <p class="text-sm font-medium text-n-slate-12 mb-1 border-b border-n-weak pb-1">Rede</p>
          <table class="w-full text-sm mt-2">
            <thead>
              <tr class="text-left text-n-slate-11">
                <th class="font-normal py-1">Interface</th><th class="font-normal">MAC</th>
                <th class="font-normal">IP</th><th class="font-normal">Máscara</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(n, i) in detail.redes" :key="i" class="text-n-slate-12">
                <td class="py-1">{{ n.DESCRIPTION || '—' }}</td>
                <td>{{ n.MACADDR || '—' }}</td>
                <td>{{ n.IPADDRESS || '—' }}</td>
                <td>{{ n.IPMASK || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Discos -->
        <div v-if="detail.discos.length">
          <p class="text-sm font-medium text-n-slate-12 mb-1 border-b border-n-weak pb-1">Discos</p>
          <table class="w-full text-sm mt-2">
            <thead>
              <tr class="text-left text-n-slate-11">
                <th class="font-normal py-1">Unidade</th><th class="font-normal">FS</th>
                <th class="font-normal">Total (MB)</th><th class="font-normal">Livre (MB)</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(d, i) in detail.discos" :key="i" class="text-n-slate-12">
                <td class="py-1">{{ d.LETTER || d.VOLUMN || '—' }}</td>
                <td>{{ d.FILESYSTEM || '—' }}</td>
                <td>{{ d.TOTAL || '—' }}</td>
                <td>{{ d.FREE || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Softwares -->
        <div v-if="detail.softwares.length">
          <p class="text-sm font-medium text-n-slate-12 mb-1 border-b border-n-weak pb-1">
            Softwares instalados ({{ detail.softwares.length }})
          </p>
          <div class="max-h-60 overflow-auto mt-2">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-n-slate-11">
                  <th class="font-normal py-1">Nome</th><th class="font-normal">Versão</th>
                  <th class="font-normal">Fabricante</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(s, i) in detail.softwares" :key="i" class="text-n-slate-12">
                  <td class="py-1 pr-2">{{ s.nome }}</td>
                  <td class="pr-2">{{ s.versao || '—' }}</td>
                  <td>{{ s.fabricante || '—' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
