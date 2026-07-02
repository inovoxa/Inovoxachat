<script setup>
import { computed, reactive, ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['save']);

const dialogRef = ref(null);
const STATUS = ['disponivel', 'alugado', 'manutencao'];
const STATUS_LABEL = {
  disponivel: 'Disponível',
  alugado: 'Alugado',
  manutencao: 'Em manutenção',
};

const form = reactive({ id: null, name: '', serial: '', status: 'disponivel' });
const isInvalid = computed(() => !form.name.trim());
const selectClass =
  'h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12';

const reset = () =>
  Object.assign(form, { id: null, name: '', serial: '', status: 'disponivel' });

const open = (eq = {}) => {
  Object.assign(form, {
    id: eq.id || null,
    name: eq.name || '',
    serial: eq.serial || '',
    status: eq.status || 'disponivel',
  });
  dialogRef.value?.open();
};

const confirm = () => {
  if (isInvalid.value) return;
  emit('save', {
    id: form.id,
    name: form.name.trim(),
    serial: form.serial.trim() || null,
    status: form.status,
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
        {{ form.id ? 'Editar equipamento' : 'Novo equipamento' }}
      </span>
      <Input v-model="form.name" placeholder="Nome do equipamento" :disabled="isLoading" autofocus />
      <Input v-model="form.serial" placeholder="Nº de série (opcional)" :disabled="isLoading" />
      <label class="flex flex-col gap-1">
        <span class="text-xs text-n-slate-11">Status</span>
        <select v-model="form.status" :disabled="isLoading" :class="selectClass">
          <option v-for="s in STATUS" :key="s" :value="s">{{ STATUS_LABEL[s] }}</option>
        </select>
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
