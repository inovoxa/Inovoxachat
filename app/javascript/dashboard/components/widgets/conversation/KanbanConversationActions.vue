<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ScheduleMessageModal from 'dashboard/routes/dashboard/kanban/components/ScheduleMessageModal.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  contactName: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('pipelines/getPipelines');

const menuOpen = ref(false);
const showSchedule = ref(false);
const showAssign = ref(false);
const selectedPipelineId = ref(null);
const selectedStageId = ref(null);
const saving = ref(false);

onMounted(() => {
  if (!pipelines.value.length) store.dispatch('pipelines/get');
});

const currentStages = computed(() => {
  const pipeline = pipelines.value.find(p => p.id === selectedPipelineId.value);
  return pipeline ? pipeline.stages : [];
});

const openSchedule = () => {
  menuOpen.value = false;
  showSchedule.value = true;
};

const openAssign = () => {
  menuOpen.value = false;
  showAssign.value = true;
  if (pipelines.value.length && !selectedPipelineId.value) {
    selectedPipelineId.value = pipelines.value[0].id;
  }
};

const confirmAssign = async () => {
  if (!selectedStageId.value) return;
  saving.value = true;
  try {
    await store.dispatch('pipelines/moveConversationToStage', {
      conversationId: props.conversationId,
      stageId: selectedStageId.value,
    });
    useAlert(t('KANBAN.CONVO_ACTIONS.ASSIGN_SUCCESS'));
    showAssign.value = false;
  } catch (e) {
    useAlert(t('KANBAN.CONVO_ACTIONS.ASSIGN_ERROR'));
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <div class="relative">
    <woot-button
      variant="smooth"
      size="small"
      color-scheme="secondary"
      icon="i-lucide-kanban"
      @click="menuOpen = !menuOpen"
    />

    <div
      v-if="menuOpen"
      v-on-clickaway="() => (menuOpen = false)"
      class="absolute right-0 top-full mt-1 z-30 w-52 rounded-lg border border-n-weak bg-n-solid-1 shadow-lg py-1"
    >
      <button
        class="w-full text-left px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-black2"
        @click="openSchedule"
      >
        {{ t('KANBAN.CONVO_ACTIONS.SCHEDULE') }}
      </button>
      <button
        class="w-full text-left px-3 py-2 text-sm text-n-slate-12 hover:bg-n-alpha-black2"
        @click="openAssign"
      >
        {{ t('KANBAN.CONVO_ACTIONS.ASSIGN') }}
      </button>
    </div>

    <ScheduleMessageModal
      v-if="showSchedule"
      :conversation-id="conversationId"
      :title="contactName"
      @close="showSchedule = false"
    />

    <div
      v-if="showAssign"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      @click.self="showAssign = false"
    >
      <div
        class="w-full max-w-sm rounded-xl bg-n-solid-1 border border-n-weak p-5 flex flex-col gap-4"
      >
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('KANBAN.CONVO_ACTIONS.ASSIGN_TITLE') }}
        </h2>

        <p v-if="!pipelines.length" class="text-sm text-n-slate-11">
          {{ t('KANBAN.CONVO_ACTIONS.NO_PIPELINES') }}
        </p>

        <template v-else>
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('KANBAN.CONVO_ACTIONS.PIPELINE') }}
            <select
              v-model="selectedPipelineId"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
              @change="selectedStageId = null"
            >
              <option v-for="p in pipelines" :key="p.id" :value="p.id">
                {{ p.name }}
              </option>
            </select>
          </label>

          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('KANBAN.CONVO_ACTIONS.STAGE') }}
            <select
              v-model="selectedStageId"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            >
              <option :value="null" disabled>
                {{ t('KANBAN.CONVO_ACTIONS.STAGE_PLACEHOLDER') }}
              </option>
              <option v-for="s in currentStages" :key="s.id" :value="s.id">
                {{ s.name }}
              </option>
            </select>
          </label>
        </template>

        <div class="flex justify-end gap-2">
          <button
            class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
            @click="showAssign = false"
          >
            {{ t('KANBAN.CONVO_ACTIONS.CANCEL') }}
          </button>
          <button
            v-if="pipelines.length"
            class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
            :disabled="!selectedStageId || saving"
            @click="confirmAssign"
          >
            {{ t('KANBAN.CONVO_ACTIONS.CONFIRM') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
