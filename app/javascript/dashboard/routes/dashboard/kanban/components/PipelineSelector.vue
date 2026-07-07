<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  pipelines: {
    type: Array,
    default: () => [],
  },
  currentId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['change']);

const { t } = useI18n();

const onChange = event => {
  emit('change', Number(event.target.value));
};
</script>

<template>
  <label class="flex items-center gap-2 text-sm text-n-slate-11">
    {{ t('KANBAN.SELECTOR.LABEL') }}
    <select
      :value="currentId || ''"
      class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-1.5 text-n-slate-12"
      @change="onChange"
    >
      <option
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        :value="pipeline.id"
      >
        {{ pipeline.name }}
      </option>
    </select>
  </label>
</template>
