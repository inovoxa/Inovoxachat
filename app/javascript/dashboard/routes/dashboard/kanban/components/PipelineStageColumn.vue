<script setup>
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';

defineProps({
  column: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['change', 'cardClick']);

const { t } = useI18n();

const PRIORITY_CLASS = {
  urgent: 'text-red-500',
  high: 'text-orange-500',
  medium: 'text-yellow-500',
  low: 'text-n-slate-11',
};

const initials = name => (name || '?').trim().charAt(0).toUpperCase();
</script>

<template>
  <div
    class="flex flex-col w-72 shrink-0 rounded-xl bg-n-alpha-black2 p-3 gap-2 border-t-4"
    :style="{ borderTopColor: column.color }"
  >
    <div class="flex items-center justify-between">
      <span
        class="text-sm font-semibold flex items-center gap-2"
        :style="{ color: column.color }"
      >
        <span
          class="w-2 h-2 rounded-full"
          :style="{ backgroundColor: column.color }"
        />
        {{ column.name }}
      </span>
      <span
        class="text-xs px-1.5 rounded-full"
        :style="{ color: column.color, backgroundColor: column.color + '22' }"
      >
        {{ column.items.length }}
      </span>
    </div>

    <Draggable
      :list="column.items"
      group="kanban-board"
      item-key="key"
      class="flex flex-col gap-2 flex-1 min-h-8 overflow-y-auto"
      @change="event => emit('change', event)"
    >
      <template #item="{ element }">
        <div
          class="rounded-lg bg-n-solid-2 border border-n-weak p-3 cursor-grab flex flex-col gap-1.5 hover:border-n-slate-7"
          @click="emit('cardClick', element)"
        >
          <template v-if="element.type === 'conversation'">
            <div class="flex items-center gap-2">
              <img
                v-if="element.contact?.thumbnail"
                :src="element.contact.thumbnail"
                class="w-6 h-6 rounded-full object-cover"
              />
              <span
                v-else
                class="w-6 h-6 rounded-full bg-woot-500/20 text-woot-500 text-xs flex items-center justify-center font-medium"
              >
                {{ initials(element.contact?.name) }}
              </span>
              <span class="text-sm text-n-slate-12 truncate flex-1">
                {{ element.contact?.name }}
              </span>
              <span
                v-if="element.priority"
                class="text-xs font-medium uppercase"
                :class="PRIORITY_CLASS[element.priority]"
              >
                {{ element.priority }}
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-xs text-n-slate-11">#{{ element.id }}</span>
              <span
                class="text-xs px-1.5 py-0.5 rounded-full bg-n-slate-4 text-n-slate-11"
              >
                {{ element.status }}
              </span>
            </div>
            <div
              v-if="element.assignee"
              class="flex items-center gap-1.5 text-xs text-n-slate-11"
            >
              <img
                v-if="element.assignee.thumbnail"
                :src="element.assignee.thumbnail"
                class="w-4 h-4 rounded-full object-cover"
              />
              <span
                v-else
                class="w-4 h-4 rounded-full bg-n-slate-4 text-n-slate-11 text-[9px] flex items-center justify-center"
              >
                {{ initials(element.assignee.name) }}
              </span>
              {{ element.assignee.name }}
            </div>
          </template>

          <template v-else>
            <div class="flex items-center gap-2">
              <img
                v-if="element.thumbnail"
                :src="element.thumbnail"
                class="w-6 h-6 rounded-full object-cover"
              />
              <span
                v-else
                class="w-6 h-6 rounded-full bg-n-teal-9/20 text-n-teal-11 text-xs flex items-center justify-center font-medium"
              >
                {{ initials(element.name) }}
              </span>
              <span class="text-sm text-n-slate-12 truncate flex-1">
                {{ element.name }}
              </span>
            </div>
            <p
              v-if="element.email || element.phone_number"
              class="text-xs text-n-slate-11 truncate"
            >
              {{ element.email || element.phone_number }}
            </p>
            <span
              class="text-xs px-1.5 py-0.5 rounded-full bg-n-teal-9/20 text-n-teal-11 self-start"
            >
              {{ t('KANBAN.BOARD.NEW_CONTACT') }}
            </span>
          </template>
        </div>
      </template>
    </Draggable>

    <p
      v-if="!column.items.length"
      class="text-xs text-n-slate-10 text-center py-2"
    >
      {{ t('KANBAN.BOARD.EMPTY_STAGE') }}
    </p>
  </div>
</template>
