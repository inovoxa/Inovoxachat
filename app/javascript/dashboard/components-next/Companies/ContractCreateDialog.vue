<script setup>
import { computed, reactive, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CompaniesAPI from 'dashboard/api/companies';
import EquipmentsAPI from 'dashboard/api/equipments';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const empresas = ref([]);
const equipamentos = ref([]);

const STATUS = ['ativo', 'vencido', 'encerrado', 'renovacao_pendente'];
const STATUS_LABEL = {
  ativo: 'Ativo',
  vencido: 'Vencido',
  encerrado: 'Encerrado',
  renovacao_pendente: 'Renovação pendente',
};

const inputClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12 w-full';

const EMPTY = () => ({
  id: null,
  company_id: '',
  start_date: '',
  end_date: '',
  value: '',
  status: 'ativo',
  notes: '',
  items: [],
});
const form = reactive(EMPTY());

const isInvalid = computed(
  () => !form.company_id || !form.start_date || !form.end_date
);

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
}

const open = async (c = {}) => {
  await carregarOpcoes();
  Object.assign(form, {
    id: c.id || null,
    company_id: c.company_id || '',
    start_date: c.start_date || '',
    end_date: c.end_date || '',
    value: c.value || '',
    status: c.status || 'ativo',
    notes: c.notes || '',
    items: (c.items || []).map(i => ({
      id: i.id || null,
      equipment_id: i.equipment_id,
      qty: i.qty,
      return_date: i.return_date || '',
    })),
  });
  dialogRef.value?.open();
};

const addItem = () => form.items.push({ id: null, equipment_id: '', qty: 1, return_date: '' });
const removeItem = i => form.items.splice(i, 1);

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    company_id: form.company_id,
    start_date: form.start_date,
    end_date: form.end_date,
    value: form.value === '' ? null : form.value,
    status: form.status,
    notes: form.notes.trim() || null,
    contract_items_attributes: form.items
      .filter(i => i.equipment_id)
      .map(i => ({
        ...(i.id ? { id: i.id } : {}),
        equipment_id: i.equipment_id,
        qty: Number(i.qty) || 1,
        return_date: i.return_date || null,
      })),
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
        {{ form.id ? 'Editar contrato' : 'Novo contrato' }}
      </span>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 sm:col-span-2">
          <span class="text-xs text-n-slate-11">Empresa</span>
          <select v-model="form.company_id" :disabled="isLoading" :class="inputClass">
            <option value="" disabled>Selecione a empresa</option>
            <option v-for="e in empresas" :key="e.id" :value="e.id">{{ e.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Início</span>
          <input v-model="form.start_date" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Término</span>
          <input v-model="form.end_date" type="date" :disabled="isLoading" :class="inputClass" />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Valor (R$)</span>
          <input
            v-model="form.value"
            type="number"
            step="0.01"
            min="0"
            placeholder="0,00"
            :disabled="isLoading"
            :class="inputClass"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-xs text-n-slate-11">Status</span>
          <select v-model="form.status" :disabled="isLoading" :class="inputClass">
            <option v-for="s in STATUS" :key="s" :value="s">{{ STATUS_LABEL[s] }}</option>
          </select>
        </label>
      </div>

      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Observações</span>
        <textarea
          v-model="form.notes"
          rows="2"
          :disabled="isLoading"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-sm text-n-slate-12"
        />
      </label>

      <!-- Itens: equipamentos alugados -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-12">Equipamentos</span>
          <button type="button" class="text-xs text-woot-500 hover:underline" @click="addItem">
            + Adicionar equipamento
          </button>
        </div>
        <div v-for="(item, i) in form.items" :key="i" class="flex items-end gap-2">
          <label class="flex flex-col gap-1 flex-1">
            <span class="text-[10px] text-n-slate-11">Equipamento</span>
            <select v-model="item.equipment_id" :class="inputClass">
              <option value="" disabled>Selecione</option>
              <option v-for="eq in equipamentos" :key="eq.id" :value="eq.id">
                {{ eq.name }}<template v-if="eq.serial"> ({{ eq.serial }})</template>
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1 w-16">
            <span class="text-[10px] text-n-slate-11">Qtd</span>
            <input v-model="item.qty" type="number" min="1" :class="inputClass" />
          </label>
          <label class="flex flex-col gap-1 w-36">
            <span class="text-[10px] text-n-slate-11">Devolução</span>
            <input v-model="item.return_date" type="date" :class="inputClass" />
          </label>
          <button
            type="button"
            class="h-8 w-8 grid place-items-center rounded-lg text-n-slate-11 hover:text-red-600 hover:bg-red-500/15"
            @click="removeItem(i)"
          >
            ✕
          </button>
        </div>
        <p v-if="!form.items.length" class="text-xs text-n-slate-11">
          Nenhum equipamento adicionado.
        </p>
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
