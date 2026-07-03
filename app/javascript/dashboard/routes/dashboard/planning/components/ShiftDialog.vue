<script setup>
import { computed, reactive, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CompaniesAPI from 'dashboard/api/companies';
import AgentAPI from 'dashboard/api/agents';

const props = defineProps({
  isLoading: { type: Boolean, default: false },
  defaultDate: { type: String, default: '' },
});
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const empresas = ref([]);
const agentes = ref([]);
const STATUS = ['provisorio', 'agendado', 'em_progresso', 'concluido'];
const STATUS_LABEL = {
  provisorio: 'Provisório',
  agendado: 'Agendado',
  em_progresso: 'Em progresso',
  concluido: 'Concluído',
};

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  resource_id: '',
  company_id: '',
  start_at: '',
  end_at: '',
  role: '',
  status: 'provisorio',
  notes: '',
});
const form = reactive(EMPTY());
const isInvalid = computed(() => !form.start_at);
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

const open = async (s = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: s.id || null,
    resource_id: s.resource_id || '',
    company_id: s.company_id || '',
    start_at: s.start_at ? s.start_at.slice(0, 16) : props.defaultDate ? `${props.defaultDate}T08:00` : '',
    end_at: s.end_at ? s.end_at.slice(0, 16) : '',
    role: s.role || '',
    status: s.status || 'provisorio',
    notes: s.notes || '',
  });
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    resource_id: form.resource_id || null,
    company_id: form.company_id || null,
    start_at: form.start_at,
    end_at: form.end_at || null,
    role: form.role.trim() || null,
    status: form.status,
    notes: form.notes.trim() || null,
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
        {{ form.id ? 'Turno' : 'Novo turno' }}
      </span>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Recurso (agente)</span>
          <select v-model="form.resource_id" :disabled="isLoading" :class="inputClass">
            <option value="">Turno aberto</option>
            <option v-for="a in agentes" :key="a.id" :value="a.id">{{ a.available_name || a.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Cliente (empresa)</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Início</span>
          <input v-model="form.start_at" type="datetime-local" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Fim</span>
          <input v-model="form.end_at" type="datetime-local" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Função</span>
          <Input v-model="form.role" placeholder="ex.: Técnico de campo" :disabled="isLoading" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Status</span>
          <select v-model="form.status" :disabled="isLoading" :class="inputClass">
            <option v-for="s in STATUS" :key="s" :value="s">{{ STATUS_LABEL[s] }}</option>
          </select>
        </label>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Nota</span>
        <textarea
          v-model="form.notes"
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
