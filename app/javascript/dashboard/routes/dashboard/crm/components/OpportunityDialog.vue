<script setup>
import { computed, reactive, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CompaniesAPI from 'dashboard/api/companies';
import AgentAPI from 'dashboard/api/agents';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save', 'ganhar', 'perder']);

const dialogRef = ref(null);
const empresas = ref([]);
const agentes = ref([]);
const contatos = ref([]);

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  name: '',
  company_id: '',
  contact_id: '',
  agent_id: '',
  expected_value: '',
  probability: 0,
  rating: 0,
  expected_closing: '',
  notes: '',
});
const form = reactive(EMPTY());
const isInvalid = computed(() => !form.name.trim());
const isEdit = computed(() => !!form.id);

const reset = () => Object.assign(form, EMPTY());

async function carregarContatos(companyId) {
  contatos.value = [];
  if (!companyId) return;
  try {
    const { data } = await CompaniesAPI.listContacts(companyId);
    contatos.value = data.payload || [];
  } catch (e) {
    contatos.value = [];
  }
}

watch(
  () => form.company_id,
  id => carregarContatos(id)
);

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

const open = async (op = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: op.id || null,
    name: op.name || '',
    company_id: op.company_id || '',
    contact_id: op.contact_id || '',
    agent_id: op.agent_id || '',
    expected_value: op.expected_value || '',
    probability: op.probability || 0,
    rating: op.rating || 0,
    expected_closing: op.expected_closing || '',
    notes: op.notes || '',
  });
  if (form.company_id) await carregarContatos(form.company_id);
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    name: form.name.trim(),
    company_id: form.company_id || null,
    contact_id: form.contact_id || null,
    agent_id: form.agent_id || null,
    expected_value: form.expected_value === '' ? 0 : form.expected_value,
    probability: Number(form.probability) || 0,
    rating: Number(form.rating) || 0,
    expected_closing: form.expected_closing || null,
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
        {{ isEdit ? 'Oportunidade' : 'Nova oportunidade' }}
      </span>

      <Input v-model="form.name" placeholder="Título da oportunidade" :disabled="isLoading" autofocus />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Empresa</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Contato</span>
          <select v-model="form.contact_id" :disabled="isLoading || !contatos.length" :class="inputClass">
            <option value="">—</option>
            <option v-for="c in contatos" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Vendedor</span>
          <select v-model="form.agent_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="a in agentes" :key="a.id" :value="a.id">{{ a.available_name || a.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Receita esperada (R$)</span>
          <input v-model="form.expected_value" type="number" step="0.01" min="0" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Probabilidade (%)</span>
          <input v-model="form.probability" type="number" min="0" max="100" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Fechamento esperado</span>
          <input v-model="form.expected_closing" type="date" :class="inputClass" />
        </label>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-xs text-n-slate-11">Prioridade:</span>
        <button
          v-for="n in 3"
          :key="n"
          type="button"
          class="text-lg"
          :class="n <= form.rating ? 'text-yellow-500' : 'text-n-slate-6'"
          @click="form.rating = form.rating === n ? 0 : n"
        >
          ★
        </button>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Notas</span>
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
        <div class="flex items-center gap-2">
          <Button label="Cancelar" variant="link" @click="dialogRef?.close()" />
          <template v-if="isEdit">
            <Button label="Ganho" color="teal" :disabled="isLoading" @click="emit('ganhar', { id: form.id })" />
            <Button label="Perdido" color="ruby" :disabled="isLoading" @click="emit('perder', { id: form.id })" />
          </template>
        </div>
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
