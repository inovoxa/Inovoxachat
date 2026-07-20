<script setup>
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { dynamicTime, messageTimestamp } from 'shared/helpers/timeHelper';

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
const relativeTime = ts => (ts ? dynamicTime(ts) : '');

// Tooltip do badge de calendário: título + data/hora do próximo evento.
// start_time vem como epoch em segundos (ver cards.json.jbuilder), igual aos
// demais timestamps do card. O try/catch existe porque o date-fns lança
// RangeError em data inválida e isso derrubava o render do board inteiro.
const nextEventTooltip = event => {
  if (!event) return '';
  if (!event.start_time) return event.title || '';
  try {
    const when = messageTimestamp(event.start_time, 'MMM d, yyyy · h:mm a');
    return `${event.title} · ${when}`;
  } catch {
    return event.title || '';
  }
};
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
            <p
              v-if="element.last_message"
              class="text-xs text-n-slate-11 line-clamp-2"
            >
              <span v-if="!element.last_message.incoming" class="text-n-slate-10"
                >↩ </span
              >{{ element.last_message.content }}
            </p>
            <div
              v-if="element.labels && element.labels.length"
              class="flex flex-wrap gap-1"
            >
              <span
                v-for="label in element.labels"
                :key="label"
                class="text-[10px] px-1.5 py-0.5 rounded-full bg-n-slate-4 text-n-slate-11"
              >
                {{ label }}
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-xs text-n-slate-11">#{{ element.id }}</span>
              <div class="flex items-center gap-1.5">
                <span
                  v-if="element.next_calendar_event"
                  v-tooltip.top="nextEventTooltip(element.next_calendar_event)"
                  class="i-lucide-calendar-clock w-3.5 h-3.5 text-woot-500"
                  @click.stop
                />
                <span
                  class="text-xs px-1.5 py-0.5 rounded-full bg-n-slate-4 text-n-slate-11"
                >
                  {{ element.status }}
                </span>
              </div>
            </div>
            <div class="flex items-center justify-between gap-2">
              <span
                v-if="element.inbox_name"
                class="text-[10px] text-n-slate-10 truncate"
              >
                {{ element.inbox_name }}
              </span>
              <span class="text-[10px] text-n-slate-10 whitespace-nowrap ml-auto">
                {{ relativeTime(element.last_activity_at) }}
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
            <div class="flex items-center justify-between gap-2">
              <span
                class="text-xs px-1.5 py-0.5 rounded-full bg-n-teal-9/20 text-n-teal-11"
              >
                {{ t('KANBAN.BOARD.NEW_CONTACT') }}
              </span>
              <span class="text-[10px] text-n-slate-10 whitespace-nowrap">
                {{ relativeTime(element.created_at) }}
              </span>
            </div>
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
