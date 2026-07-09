<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  selectedAgentIds: {
    type: Array,
    default: () => [],
  },
  selectedPipelineIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'update:selectedAgentIds',
  'update:selectedPipelineIds',
]);

const store = useStore();
const { t } = useI18n();

const agents = useMapGetter('agents/getAgents');
const pipelines = useMapGetter('pipelines/getPipelines');

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
  if (!pipelines.value.length) store.dispatch('pipelines/get');
});

const hasFilters = computed(
  () => props.selectedAgentIds.length || props.selectedPipelineIds.length
);

const toggle = (list, id, event) => {
  const next = event.target.checked
    ? [...list, id]
    : list.filter(item => item !== id);
  return next;
};

const onAgentToggle = (id, event) => {
  emit('update:selectedAgentIds', toggle(props.selectedAgentIds, id, event));
};

const onPipelineToggle = (id, event) => {
  emit(
    'update:selectedPipelineIds',
    toggle(props.selectedPipelineIds, id, event)
  );
};

const clearFilters = () => {
  emit('update:selectedAgentIds', []);
  emit('update:selectedPipelineIds', []);
};
</script>

<template>
  <aside
    class="w-56 shrink-0 h-full overflow-y-auto border-r border-n-weak p-4 flex flex-col gap-5"
  >
    <div class="flex items-center justify-between">
      <h2 class="text-sm font-medium text-n-slate-12">
        {{ t('CALENDAR.FILTERS.TITLE') }}
      </h2>
      <button
        v-if="hasFilters"
        class="text-xs text-woot-500 hover:underline"
        @click="clearFilters"
      >
        {{ t('CALENDAR.FILTERS.CLEAR') }}
      </button>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-xs font-medium uppercase text-n-slate-10">
        {{ t('CALENDAR.FILTERS.AGENTS') }}
      </span>
      <label
        v-for="agent in agents"
        :key="agent.id"
        class="flex items-center gap-2 text-sm text-n-slate-11 cursor-pointer"
      >
        <input
          type="checkbox"
          :checked="selectedAgentIds.includes(agent.id)"
          @change="onAgentToggle(agent.id, $event)"
        />
        <span class="truncate">{{ agent.name }}</span>
      </label>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-xs font-medium uppercase text-n-slate-10">
        {{ t('CALENDAR.FILTERS.PIPELINES') }}
      </span>
      <label
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        class="flex items-center gap-2 text-sm text-n-slate-11 cursor-pointer"
      >
        <input
          type="checkbox"
          :checked="selectedPipelineIds.includes(pipeline.id)"
          @change="onPipelineToggle(pipeline.id, $event)"
        />
        <span class="truncate">{{ pipeline.name }}</span>
      </label>
    </div>
  </aside>
</template>
