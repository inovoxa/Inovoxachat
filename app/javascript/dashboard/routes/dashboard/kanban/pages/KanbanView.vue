<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import PipelineSelector from '../components/PipelineSelector.vue';
import PipelineCreateModal from '../components/PipelineCreateModal.vue';
import PipelineSettingsModal from '../components/PipelineSettingsModal.vue';
import PipelineBoard from '../components/PipelineBoard.vue';

const PERIODS = [7, 30, 90, 180];

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('pipelines/getPipelines');
const currentPipeline = useMapGetter('pipelines/getCurrentPipeline');
const board = useMapGetter('pipelines/getBoard');
const uiFlags = useMapGetter('pipelines/getUIFlags');
const currentRole = useMapGetter('getCurrentRole');

const isAdmin = computed(() => currentRole.value === 'administrator');
const days = ref(30);
const showCreateModal = ref(false);
const showSettingsModal = ref(false);

const boardStages = computed(() =>
  board.value.pipelineId === currentPipeline.value?.id
    ? board.value.stages
    : []
);

const loadCards = () => {
  if (!currentPipeline.value?.id) return;
  store.dispatch('pipelines/fetchCards', {
    pipelineId: currentPipeline.value.id,
    days: days.value,
  });
};

onMounted(async () => {
  await store.dispatch('pipelines/get');
  loadCards();
});

watch(() => currentPipeline.value?.id, loadCards);
watch(days, loadCards);

const onPipelineChange = pipelineId => {
  store.dispatch('pipelines/setCurrentPipeline', pipelineId);
};

const onPipelineDeleted = () => {
  showSettingsModal.value = false;
  store.dispatch('pipelines/setCurrentPipeline', null);
};
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden p-6 gap-4">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div class="flex items-center gap-3 flex-wrap">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('KANBAN.HEADER') }}
        </h1>
        <PipelineSelector
          v-if="pipelines.length"
          :pipelines="pipelines"
          :current-id="currentPipeline.id"
          @change="onPipelineChange"
        />
      </div>

      <div class="flex items-center gap-2 flex-wrap">
        <div
          class="flex items-center rounded-lg border border-n-weak bg-n-alpha-black2 p-0.5"
        >
          <button
            v-for="period in PERIODS"
            :key="period"
            class="px-2.5 py-1 text-xs rounded-md"
            :class="
              days === period
                ? 'bg-woot-500 text-white font-medium'
                : 'text-n-slate-11 hover:text-n-slate-12'
            "
            @click="days = period"
          >
            {{ t(`KANBAN.PERIOD.D${period}`) }}
          </button>
        </div>
        <button
          v-if="isAdmin && currentPipeline.id"
          class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
          @click="showSettingsModal = true"
        >
          {{ t('KANBAN.SETTINGS') }}
        </button>
        <button
          v-if="isAdmin"
          class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600"
          @click="showCreateModal = true"
        >
          {{ t('KANBAN.NEW_PIPELINE') }}
        </button>
      </div>
    </div>

    <p
      v-if="currentPipeline.description"
      class="text-sm text-n-slate-11 -mt-2"
    >
      {{ currentPipeline.description }}
    </p>

    <div
      v-if="!pipelines.length && !uiFlags.isFetching"
      class="flex flex-col items-center justify-center flex-1 gap-2 text-center"
    >
      <h2 class="text-lg font-medium text-n-slate-12">
        {{ t('KANBAN.EMPTY.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11 max-w-md">
        {{ t('KANBAN.EMPTY.DESCRIPTION') }}
      </p>
      <button
        v-if="isAdmin"
        class="mt-2 px-4 py-2 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600"
        @click="showCreateModal = true"
      >
        {{ t('KANBAN.EMPTY.CREATE') }}
      </button>
    </div>

    <p v-else-if="uiFlags.isFetching" class="text-n-slate-11">
      {{ t('KANBAN.LOADING') }}
    </p>

    <PipelineBoard
      v-else
      :stages="boardStages"
      :loading="uiFlags.isFetchingBoard"
      @reload="loadCards"
    />

    <PipelineCreateModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @created="showCreateModal = false"
    />

    <PipelineSettingsModal
      v-if="showSettingsModal && currentPipeline.id"
      :pipeline="currentPipeline"
      @close="showSettingsModal = false"
      @updated="loadCards"
      @deleted="onPipelineDeleted"
    />
  </div>
</template>
