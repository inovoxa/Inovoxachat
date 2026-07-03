<script setup>
import { computed, reactive, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CompaniesAPI from 'dashboard/api/companies';
import AgentAPI from 'dashboard/api/agents';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const empresas = ref([]);
const agentes = ref([]);

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  title: '',
  company_id: '',
  organizer_id: '',
  start_at: '',
  end_at: '',
  location: '',
  description: '',
  participant_ids: [],
});
const form = reactive(EMPTY());
const isInvalid = computed(() => !form.title.trim() || !form.start_at);
const reset = () => Object.assign(form, EMPTY());

async function carregarOpcoes() {
  try {
    const { data } = await CompaniesAPI.get({});
    empresas.value = data.payload || [];
  } catch (e) {
    empresas.value = [];
  }
  try {
    const { data } = await AgentAPI.get();
    agentes.value = data || [];
  } catch (e) {
    agentes.value = [];
  }
}

const open = async (m = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: m.id || null,
    title: m.title || '',
    company_id: m.company_id || '',
    organizer_id: m.organizer_id || '',
    start_at: m.start_at ? m.start_at.slice(0, 16) : m.defaultStart || '',
    end_at: m.end_at ? m.end_at.slice(0, 16) : '',
    location: m.location || '',
    description: m.description || '',
    participant_ids: (m.participant_ids || []).map(String),
  });
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    title: form.title.trim(),
    company_id: form.company_id || null,
    organizer_id: form.organizer_id || null,
    start_at: form.start_at,
    end_at: form.end_at || null,
    location: form.location.trim() || null,
    description: form.description.trim() || null,
    participant_ids: form.participant_ids.map(Number),
  });
};

const onSuccess = () => {
  reset();
  dialogRef.value?.close();
};

defineExpose({ open, onSuccess, dialogRef });
</script>

<template>
  <Dialog ref="dialogRef" width="2xl" :show-confirm-button="false" @confirm="confirm" @close="reset">
    <div class="flex flex-col gap-4">
      <span class="text-sm font-medium text-n-slate-12">
        {{ form.id ? 'Reunião' : 'Nova reunião' }}
      </span>

      <Input v-model="form.title" placeholder="Título da reunião" :disabled="isLoading" autofocus />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Início</span>
          <input v-model="form.start_at" type="datetime-local" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Fim</span>
          <input v-model="form.end_at" type="datetime-local" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Local</span>
          <Input v-model="form.location" placeholder="ex.: Sala 2 / Google Meet" :disabled="isLoading" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Empresa</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Organizador</span>
          <select v-model="form.organizer_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="a in agentes" :key="a.id" :value="a.id">{{ a.available_name || a.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Participantes</span>
          <select v-model="form.participant_ids" multiple :disabled="isLoading" class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1 text-sm text-n-slate-12 h-20">
            <option v-for="a in agentes" :key="a.id" :value="String(a.id)">{{ a.available_name || a.name }}</option>
          </select>
        </label>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Descrição</span>
        <textarea
          v-model="form.description"
          rows="2"
          :disabled="isLoading"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
      </label>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button label="Cancelar" variant="link" @click="dialogRef?.close()" />
        <Button
          label="Salvar"
          color="blue"
          type="submit"
          :disabled="isInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
