<script setup>
import { computed, reactive, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CompaniesAPI from 'dashboard/api/companies';
import ContractsAPI from 'dashboard/api/contracts';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const empresas = ref([]);
const contratos = ref([]);

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  company_id: '',
  contract_id: '',
  due_date: '',
  amount: '',
});
const form = reactive(EMPTY());
const isInvalid = computed(() => !form.company_id || !form.due_date);

const reset = () => Object.assign(form, EMPTY());

async function carregarContratos(companyId) {
  contratos.value = [];
  if (!companyId) return;
  try {
    const { data } = await ContractsAPI.get({ company_id: companyId });
    contratos.value = data.payload || [];
  } catch (e) {
    contratos.value = [];
  }
}

watch(
  () => form.company_id,
  id => carregarContratos(id)
);

const open = async (inv = {}) => {
  try {
    const { data } = await CompaniesAPI.get({});
    empresas.value = data.payload || [];
  } catch (e) {
    empresas.value = [];
  }
  Object.assign(form, {
    id: inv.id || null,
    company_id: inv.company_id || '',
    contract_id: inv.contract_id || '',
    due_date: inv.due_date || '',
    amount: inv.amount || '',
  });
  if (form.company_id) await carregarContratos(form.company_id);
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    company_id: form.company_id,
    contract_id: form.contract_id || null,
    due_date: form.due_date,
    amount: form.amount === '' ? null : form.amount,
  });
};

const onSuccess = () => {
  reset();
  dialogRef.value?.close();
};

defineExpose({ open, onSuccess, dialogRef });
</script>

<template>
  <Dialog ref="dialogRef" width="lg" :show-confirm-button="false" @confirm="confirm" @close="reset">
    <div class="flex flex-col gap-4">
      <span class="text-sm font-medium text-n-slate-12">
        {{ form.id ? 'Editar fatura' : 'Nova fatura' }}
      </span>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Empresa</span>
        <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
          <option value="">Selecione a empresa</option>
          <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
        </select>
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Contrato (opcional)</span>
        <select v-model="form.contract_id" :disabled="isLoading || !contratos.length" :class="inputClass">
          <option value="">—</option>
          <option v-for="c in contratos" :key="c.id" :value="c.id">
            #{{ c.id }} · vence {{ c.end_date }}
          </option>
        </select>
      </label>

      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Vencimento</span>
          <input v-model="form.due_date" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Valor (R$)</span>
          <input v-model="form.amount" type="number" step="0.01" min="0" :disabled="isLoading" :class="inputClass" />
        </label>
      </div>
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
