<script setup>
import { computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);

const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

onMounted(() => {
  if (!inboxes.value.length) store.dispatch('inboxes/get');
});

const selected = computed(() => props.modelValue.map(Number));

const toggle = inboxId => {
  const id = Number(inboxId);
  const next = selected.value.includes(id)
    ? selected.value.filter(item => item !== id)
    : [...selected.value, id];
  emit('update:modelValue', next);
};
</script>

<template>
  <div class="flex flex-col gap-1.5 max-h-40 overflow-y-auto rounded-lg border border-n-weak bg-n-alpha-black2 p-2">
    <label
      v-for="inbox in inboxes"
      :key="inbox.id"
      class="flex items-center gap-2 text-sm text-n-slate-12 cursor-pointer px-1 py-0.5 rounded hover:bg-n-alpha-black2"
    >
      <input
        type="checkbox"
        :checked="selected.includes(Number(inbox.id))"
        class="accent-woot-500"
        @change="toggle(inbox.id)"
      />
      {{ inbox.name }}
    </label>
    <p v-if="!inboxes.length" class="text-xs text-n-slate-10 px-1">
      —
    </p>
  </div>
</template>
