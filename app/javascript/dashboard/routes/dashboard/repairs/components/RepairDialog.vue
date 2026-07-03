<script setup>
import { reactive, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import CompaniesAPI from 'dashboard/api/companies';
import EquipmentsAPI from 'dashboard/api/equipments';
import AgentAPI from 'dashboard/api/agents';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const empresas = ref([]);
const equipamentos = ref([]);
const agentes = ref([]);

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  company_id: '',
  equipment_id: '',
  product_name: '',
  assignee_id: '',
  scheduled_at: '',
  in_warranty: false,
  notes: '',
});
const form = reactive(EMPTY());
const reset = () => Object.assign(form, EMPTY());

async function carregarOpcoes() {
  try {
    const { data } = await CompaniesAPI.get({});
    empresas.value = data.payload || [];
  } catch (e) {
    empresas.value = [];
  }
  try {
    const { data } = await EquipmentsAPI.get({});
    equipamentos.value = data.payload || [];
  } catch (e) {
    equipamentos.value = [];
  }
  try {
    const { data } = await AgentAPI.get();
    agentes.value = data || [];
  } catch (e) {
    agentes.value = [];
  }
}

const open = async (o = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: o.id || null,
    company_id: o.company_id || '',
    equipment_id: o.equipment_id || '',
    product_name: o.product_name || '',
    assignee_id: o.assignee_id || '',
    scheduled_at: o.scheduled_at ? o.scheduled_at.slice(0, 16) : '',
    in_warranty: !!o.in_warranty,
    notes: o.notes || '',
  });
  dialogRef.value?.open();
};

const confirm = () => {
  emit('save', {
    id: form.id,
    company_id: form.company_id || null,
    equipment_id: form.equipment_id || null,
    product_name: form.product_name.trim() || null,
    assignee_id: form.assignee_id || null,
    scheduled_at: form.scheduled_at || null,
    in_warranty: form.in_warranty,
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
        {{ form.id ? 'Ordem de reparo' : 'Nova ordem de reparo' }}
      </span>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Cliente (empresa)</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Equipamento (do inventário)</span>
          <select v-model="form.equipment_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="eq in equipamentos" :key="eq.id" :value="eq.id">{{ eq.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1 sm:col-span-2">
          <span class="text-xs text-n-slate-11">Produto a reparar (descrição)</span>
          <Input v-model="form.product_name" placeholder="ex.: Impressora HP LaserJet" :disabled="isLoading" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Data agendada</span>
          <input v-model="form.scheduled_at" type="datetime-local" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Responsável</span>
          <select v-model="form.assignee_id" :disabled="isLoading" :class="inputClass">
            <option value="">—</option>
            <option v-for="a in agentes" :key="a.id" :value="a.id">{{ a.available_name || a.name }}</option>
          </select>
        </label>
      </div>

      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="form.in_warranty" type="checkbox" :disabled="isLoading" />
        Na garantia
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Notas de reparo</span>
        <textarea
          v-model="form.notes"
          rows="3"
          :disabled="isLoading"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
      </label>
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button label="Cancelar" variant="link" @click="dialogRef?.close()" />
        <Button label="Salvar" color="blue" type="submit" :disabled="isLoading" :is-loading="isLoading" />
      </div>
    </template>
  </Dialog>
</template>
