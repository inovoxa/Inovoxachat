<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

defineProps({
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['create']);

const { t } = useI18n();
const dialogRef = ref(null);

const STATUS_OPTIONS = ['lead', 'ativo', 'inativo', 'churn'];

const form = reactive({
  name: '',
  domain: '',
  description: '',
  cnpj: '',
  phone: '',
  status: 'lead',
  address: '',
});

const isFormInvalid = computed(() => !form.name.trim());

const resetForm = () => {
  form.name = '';
  form.domain = '';
  form.description = '';
  form.cnpj = '';
  form.phone = '';
  form.status = 'lead';
  form.address = '';
};

const open = (company = {}) => {
  form.name = company.name || '';
  form.domain = company.domain || '';
  form.description = company.description || '';
  form.cnpj = company.cnpj || '';
  form.phone = company.phone || '';
  form.status = company.status || 'lead';
  form.address = company.address || '';
  dialogRef.value?.open();
};

const handleConfirm = () => {
  if (isFormInvalid.value) return;

  emit('create', {
    name: form.name.trim(),
    domain: form.domain.trim() || null,
    description: form.description.trim() || null,
    cnpj: form.cnpj.trim() || null,
    phone: form.phone.trim() || null,
    status: form.status,
    address: form.address.trim() || null,
  });
};

const closeDialog = () => {
  dialogRef.value?.close();
};

const onSuccess = () => {
  resetForm();
  closeDialog();
};

defineExpose({ dialogRef, onSuccess, open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    @confirm="handleConfirm"
    @close="resetForm"
  >
    <div class="flex flex-col gap-6">
      <div class="flex flex-col items-start gap-2">
        <span class="py-1 text-sm font-medium text-n-slate-12">
          {{ t('COMPANIES.CREATE.TITLE') }}
        </span>
        <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
          <Input
            v-model="form.name"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.NAME')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
            autofocus
          />
          <Input
            v-model="form.domain"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.DOMAIN')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
          <Input
            v-model="form.cnpj"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.CNPJ')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
          <Input
            v-model="form.phone"
            :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.PHONE')"
            :disabled="isLoading"
            custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
          />
          <label class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">{{ t('COMPANIES.DETAIL.PROFILE.FIELDS.STATUS') }}</span>
            <select
              v-model="form.status"
              :disabled="isLoading"
              class="h-8 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 text-sm text-n-slate-12"
            >
              <option v-for="opt in STATUS_OPTIONS" :key="opt" :value="opt">
                {{ t(`COMPANIES.STATUS.${opt.toUpperCase()}`) }}
              </option>
            </select>
          </label>
        </div>
      </div>
      <Input
        v-model="form.address"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.FIELDS.ADDRESS')"
        :disabled="isLoading"
        custom-input-class="h-8 !pt-1 !pb-1 [&:not(.error,.focus)]:!outline-transparent"
      />
      <TextArea
        v-model="form.description"
        :placeholder="t('COMPANIES.DETAIL.PROFILE.DESCRIPTION_PLACEHOLDER')"
        :disabled="isLoading"
        :max-length="280"
        class="w-full"
        show-character-count
        auto-height
      />
    </div>

    <template #footer>
      <div class="flex items-center justify-between w-full gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          variant="link"
          type="reset"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click="closeDialog"
        />
        <Button
          :label="t('COMPANIES.CREATE.ACTIONS.SAVE')"
          color="blue"
          type="submit"
          :disabled="isFormInvalid || isLoading"
          :is-loading="isLoading"
        />
      </div>
    </template>
  </Dialog>
</template>
