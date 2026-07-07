<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const emit = defineEmits(['close', 'created']);

const store = useStore();
const { t } = useI18n();

const templates = useMapGetter('pipelines/getTemplates');
const uiFlags = useMapGetter('pipelines/getUIFlags');

const name = ref('');
const description = ref('');
const selectedTemplate = ref('custom');
const autoAddMode = ref('disabled');
const error = ref('');

const AUTO_ADD_OPTIONS = ['disabled', 'new_conversations', 'new_contacts'];

onMounted(() => {
  store.dispatch('pipelines/fetchTemplates');
});

const previewStages = computed(() => {
  if (selectedTemplate.value === 'custom') {
    return [{ name: t('KANBAN.CREATE_MODAL.CUSTOM_LABEL'), color: '#1F93FF' }];
  }
  const template = templates.value.find(
    item => item.key === selectedTemplate.value
  );
  return template ? template.stages : [];
});

const onSubmit = async () => {
  if (!name.value.trim()) return;
  error.value = '';
  try {
    await store.dispatch('pipelines/create', {
      name: name.value.trim(),
      description: description.value.trim(),
      template_key:
        selectedTemplate.value === 'custom' ? null : selectedTemplate.value,
      auto_add_mode: autoAddMode.value,
    });
    emit('created');
  } catch (e) {
    error.value = e.message || t('KANBAN.CREATE_MODAL.ERROR');
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-xl rounded-xl bg-n-solid-1 border border-n-weak p-5 flex flex-col gap-4 max-h-[85vh] overflow-y-auto"
    >
      <h2 class="text-lg font-medium text-n-slate-12">
        {{ t('KANBAN.CREATE_MODAL.TITLE') }}
      </h2>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.CREATE_MODAL.NAME_LABEL') }}
        <input
          v-model="name"
          type="text"
          :placeholder="t('KANBAN.CREATE_MODAL.NAME_PLACEHOLDER')"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.CREATE_MODAL.DESCRIPTION_LABEL') }}
        <input
          v-model="description"
          type="text"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <div class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('KANBAN.CREATE_MODAL.TEMPLATE_LABEL') }}
        </span>
        <div class="grid grid-cols-2 gap-2">
          <button
            v-for="template in templates"
            :key="template.key"
            class="rounded-lg border p-3 text-left flex flex-col gap-1"
            :class="
              selectedTemplate === template.key
                ? 'border-woot-500 bg-woot-500/10'
                : 'border-n-weak hover:border-n-slate-7'
            "
            @click="selectedTemplate = template.key"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ template.label }}
            </span>
            <span class="text-xs text-n-slate-11 truncate">
              {{ template.stages.map(stage => stage.name).join(' → ') }}
            </span>
          </button>
          <button
            class="rounded-lg border p-3 text-left flex flex-col gap-1"
            :class="
              selectedTemplate === 'custom'
                ? 'border-woot-500 bg-woot-500/10'
                : 'border-n-weak hover:border-n-slate-7'
            "
            @click="selectedTemplate = 'custom'"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('KANBAN.CREATE_MODAL.CUSTOM_LABEL') }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{ t('KANBAN.CREATE_MODAL.CUSTOM_DESCRIPTION') }}
            </span>
          </button>
        </div>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('KANBAN.CREATE_MODAL.PREVIEW_LABEL') }}
        </span>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="stage in previewStages"
            :key="stage.name"
            class="text-xs px-2 py-1 rounded-full flex items-center gap-1.5 border border-n-weak text-n-slate-12"
          >
            <span
              class="w-2 h-2 rounded-full"
              :style="{ backgroundColor: stage.color }"
            />
            {{ stage.name }}
          </span>
        </div>
        <p class="text-xs text-n-slate-10">
          {{ t('KANBAN.CREATE_MODAL.PREVIEW_HINT') }}
        </p>
      </div>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.CREATE_MODAL.AUTO_ADD.LABEL') }}
        <select
          v-model="autoAddMode"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        >
          <option v-for="option in AUTO_ADD_OPTIONS" :key="option" :value="option">
            {{ t(`KANBAN.CREATE_MODAL.AUTO_ADD.${option.toUpperCase()}`) }}
          </option>
        </select>
      </label>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <div class="flex justify-end gap-2">
        <button
          class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
          @click="emit('close')"
        >
          {{ t('KANBAN.CREATE_MODAL.CANCEL') }}
        </button>
        <button
          class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
          :disabled="!name.trim() || uiFlags.isCreating"
          @click="onSubmit"
        >
          {{ t('KANBAN.CREATE_MODAL.SUBMIT') }}
        </button>
      </div>
    </div>
  </div>
</template>
