<script setup>
import { reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useStore } from 'dashboard/composables/store';
import InboxMultiSelect from './InboxMultiSelect.vue';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'updated', 'deleted']);

const store = useStore();
const { t } = useI18n();

const AUTO_ADD_OPTIONS = ['disabled', 'new_conversations', 'new_contacts'];

const form = reactive({
  name: props.pipeline.name,
  description: props.pipeline.description || '',
  auto_add_mode: props.pipeline.auto_add_mode,
  inbox_ids: [...(props.pipeline.inbox_ids || [])],
});

const stages = ref([]);
const newStageName = ref('');
const newStageColor = ref('#1F93FF');
const confirmingStageId = ref(null);
const confirmingPipeline = ref(false);
const saving = ref(false);
const error = ref('');

// Recarrega a lista local a partir do store preservando edições não salvas.
const syncStages = () => {
  const edited = new Map(
    stages.value.map(stage => [stage.id, stage])
  );
  stages.value = (props.pipeline.stages || []).map(stage => {
    const local = edited.get(stage.id);
    return {
      ...stage,
      name: local?.dirty ? local.name : stage.name,
      color: local?.dirty ? local.color : stage.color,
      mapped_status: local?.dirty ? local.mapped_status : stage.mapped_status,
      dirty: local?.dirty || false,
    };
  });
};

const STATUS_OPTIONS = ['open', 'pending', 'snoozed', 'resolved'];

watch(() => props.pipeline.stages, syncStages, { immediate: true, deep: true });

const markDirty = stage => {
  stage.dirty = true;
};

const onAddStage = async () => {
  if (!newStageName.value.trim()) return;
  error.value = '';
  try {
    await store.dispatch('pipelines/createStage', {
      pipelineId: props.pipeline.id,
      name: newStageName.value.trim(),
      color: newStageColor.value,
    });
    newStageName.value = '';
    newStageColor.value = '#1F93FF';
    emit('updated');
  } catch (e) {
    error.value = t('KANBAN.SETTINGS_MODAL.ERROR');
  }
};

const onDeleteStage = async stage => {
  if (confirmingStageId.value !== stage.id) {
    confirmingStageId.value = stage.id;
    return;
  }
  confirmingStageId.value = null;
  error.value = '';
  try {
    await store.dispatch('pipelines/deleteStage', {
      pipelineId: props.pipeline.id,
      id: stage.id,
    });
    emit('updated');
  } catch (e) {
    error.value = t('KANBAN.SETTINGS_MODAL.ERROR');
  }
};

const onSave = async () => {
  saving.value = true;
  error.value = '';
  try {
    await store.dispatch('pipelines/update', {
      id: props.pipeline.id,
      name: form.name,
      description: form.description,
      auto_add_mode: form.auto_add_mode,
      inbox_ids: form.inbox_ids,
    });
    const dirtyStages = stages.value.filter(stage => stage.dirty);
    await Promise.all(
      dirtyStages.map(stage =>
        store.dispatch('pipelines/updateStage', {
          pipelineId: props.pipeline.id,
          id: stage.id,
          name: stage.name,
          color: stage.color,
          mapped_status: stage.mapped_status || null,
        })
      )
    );
    await store.dispatch('pipelines/reorderStages', {
      pipelineId: props.pipeline.id,
      stageIds: stages.value.map(stage => stage.id),
    });
    emit('updated');
    emit('close');
  } catch (e) {
    error.value = t('KANBAN.SETTINGS_MODAL.ERROR');
  } finally {
    saving.value = false;
  }
};

const onDeletePipeline = async () => {
  if (!confirmingPipeline.value) {
    confirmingPipeline.value = true;
    return;
  }
  error.value = '';
  try {
    await store.dispatch('pipelines/delete', props.pipeline.id);
    emit('deleted');
  } catch (e) {
    error.value = t('KANBAN.SETTINGS_MODAL.ERROR');
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
        {{ t('KANBAN.SETTINGS_MODAL.TITLE') }}
      </h2>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SETTINGS_MODAL.NAME_LABEL') }}
        <input
          v-model="form.name"
          type="text"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SETTINGS_MODAL.DESCRIPTION_LABEL') }}
        <input
          v-model="form.description"
          type="text"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SETTINGS_MODAL.AUTO_ADD_LABEL') }}
        <select
          v-model="form.auto_add_mode"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        >
          <option v-for="option in AUTO_ADD_OPTIONS" :key="option" :value="option">
            {{ t(`KANBAN.CREATE_MODAL.AUTO_ADD.${option.toUpperCase()}`) }}
          </option>
        </select>
      </label>

      <div class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SETTINGS_MODAL.INBOXES_LABEL') }}
        <InboxMultiSelect v-model="form.inbox_ids" />
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('KANBAN.SETTINGS_MODAL.STAGES_LABEL') }}
        </span>
        <p class="text-xs text-n-slate-10">
          {{ t('KANBAN.SETTINGS_MODAL.REORDER_HINT') }}
        </p>
        <Draggable
          v-model="stages"
          item-key="id"
          handle=".drag-handle"
          class="flex flex-col gap-1.5"
        >
          <template #item="{ element }">
            <div
              class="flex items-center gap-2 rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5"
            >
              <span class="drag-handle cursor-grab text-n-slate-10 select-none">
                ⠿
              </span>
              <input
                v-model="element.color"
                type="color"
                class="w-7 h-7 rounded cursor-pointer border-0 bg-transparent p-0"
                @input="markDirty(element)"
              />
              <input
                v-model="element.name"
                type="text"
                class="flex-1 text-sm rounded-md border border-transparent bg-transparent px-2 py-1 text-n-slate-12 focus:border-n-weak"
                @input="markDirty(element)"
              />
              <select
                v-model="element.mapped_status"
                :title="t('KANBAN.SETTINGS_MODAL.MAPPED_STATUS_TITLE')"
                class="text-xs rounded-md border border-n-weak bg-n-alpha-black2 px-1.5 py-1 text-n-slate-11"
                @change="markDirty(element)"
              >
                <option :value="null">
                  {{ t('KANBAN.SETTINGS_MODAL.STATUS.NONE') }}
                </option>
                <option v-for="s in STATUS_OPTIONS" :key="s" :value="s">
                  {{ t(`KANBAN.SETTINGS_MODAL.STATUS.${s.toUpperCase()}`) }}
                </option>
              </select>
              <button
                class="text-xs px-2 py-1 rounded-md"
                :class="
                  confirmingStageId === element.id
                    ? 'bg-red-500 text-white'
                    : 'text-red-500 hover:bg-red-500/10'
                "
                @click="onDeleteStage(element)"
              >
                {{
                  confirmingStageId === element.id
                    ? t('KANBAN.SETTINGS_MODAL.CONFIRM')
                    : t('KANBAN.SETTINGS_MODAL.DELETE_STAGE')
                }}
              </button>
            </div>
          </template>
        </Draggable>

        <div class="flex items-center gap-2">
          <input
            v-model="newStageColor"
            type="color"
            class="w-7 h-7 rounded cursor-pointer border-0 bg-transparent p-0"
          />
          <input
            v-model="newStageName"
            type="text"
            :placeholder="t('KANBAN.SETTINGS_MODAL.ADD_STAGE_PLACEHOLDER')"
            class="flex-1 text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12"
            @keyup.enter="onAddStage"
          />
          <button
            class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2 disabled:opacity-50"
            :disabled="!newStageName.trim()"
            @click="onAddStage"
          >
            {{ t('KANBAN.SETTINGS_MODAL.ADD_STAGE') }}
          </button>
        </div>
      </div>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <div class="flex items-center justify-between gap-2 flex-wrap">
        <div class="flex flex-col gap-0.5">
          <button
            class="text-sm text-left"
            :class="
              confirmingPipeline
                ? 'text-white bg-red-500 px-3 py-1.5 rounded-lg'
                : 'text-red-500 hover:underline'
            "
            @click="onDeletePipeline"
          >
            {{
              confirmingPipeline
                ? t('KANBAN.SETTINGS_MODAL.CONFIRM')
                : t('KANBAN.SETTINGS_MODAL.DELETE_PIPELINE')
            }}
          </button>
          <span class="text-xs text-n-slate-10">
            {{ t('KANBAN.SETTINGS_MODAL.DELETE_PIPELINE_HINT') }}
          </span>
        </div>
        <div class="flex gap-2">
          <button
            class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
            @click="emit('close')"
          >
            {{ t('KANBAN.SETTINGS_MODAL.CANCEL') }}
          </button>
          <button
            class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
            :disabled="saving || !form.name.trim()"
            @click="onSave"
          >
            {{ t('KANBAN.SETTINGS_MODAL.SAVE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
