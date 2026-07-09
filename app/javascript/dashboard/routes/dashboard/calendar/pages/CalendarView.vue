<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';
import interactionPlugin from '@fullcalendar/interaction';
import CalendarEventModal from '../components/CalendarEventModal.vue';
import CalendarSidebarFilters from '../components/CalendarSidebarFilters.vue';

const store = useStore();
const { t } = useI18n();

const records = useMapGetter('calendarEvents/getCalendarEvents');
const uiFlags = useMapGetter('calendarEvents/getUIFlags');

const calendarRef = ref(null);

// Filtros client-side (vazio = todos). Evita a limitação de valor único do
// backend e permite multi-seleção livre sobre o intervalo já carregado.
const selectedAgentIds = ref([]);
const selectedPipelineIds = ref([]);

const showModal = ref(false);
const editingEvent = ref(null);
const presetTimes = ref(null);

const SOURCE_COLORS = {
  internal: '#1F93FF',
  google: '#10B981',
  outlook: '#8B5CF6',
};

const visibleRecords = computed(() =>
  records.value.filter(record => {
    const agentOk =
      !selectedAgentIds.value.length ||
      selectedAgentIds.value.includes(record.user_id);
    const pipelineOk =
      !selectedPipelineIds.value.length ||
      selectedPipelineIds.value.includes(record.pipeline_stage?.pipeline?.id);
    return agentOk && pipelineOk;
  })
);

const calendarEvents = computed(() =>
  visibleRecords.value.map(record => ({
    id: record.occurrence_id || String(record.id),
    title: record.title,
    start: record.start_time,
    end: record.end_time,
    allDay: record.all_day,
    backgroundColor: SOURCE_COLORS[record.source] || SOURCE_COLORS.internal,
    borderColor: SOURCE_COLORS[record.source] || SOURCE_COLORS.internal,
    editable: record.source === 'internal',
    extendedProps: { record },
  }))
);

const loadRange = async ({ startStr, endStr }) => {
  await store.dispatch('calendarEvents/fetch', {
    startDate: startStr,
    endDate: endStr,
  });
};

const calendarOptions = computed(() => ({
  plugins: [dayGridPlugin, timeGridPlugin, listPlugin, interactionPlugin],
  initialView: 'dayGridMonth',
  headerToolbar: {
    left: 'prev,next today',
    center: 'title',
    right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek',
  },
  buttonText: {
    today: t('CALENDAR.VIEWS.TODAY') || 'today',
    month: t('CALENDAR.VIEWS.MONTH'),
    week: t('CALENDAR.VIEWS.WEEK'),
    day: t('CALENDAR.VIEWS.DAY'),
    list: t('CALENDAR.VIEWS.AGENDA'),
  },
  height: '100%',
  nowIndicator: true,
  events: calendarEvents.value,
  datesSet: loadRange,
  eventClick: onEventClick,
  dateClick: onDateClick,
}));

function onEventClick(info) {
  const { record } = info.event.extendedProps;
  editingEvent.value = record;
  presetTimes.value = null;
  showModal.value = true;
}

function onDateClick(info) {
  editingEvent.value = null;
  const start = info.date;
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  presetTimes.value = { start, end, allDay: info.allDay };
  showModal.value = true;
}

const openNewEvent = () => {
  editingEvent.value = null;
  presetTimes.value = null;
  showModal.value = true;
};

const onSaved = async () => {
  showModal.value = false;
  // Recarrega o intervalo visível atual.
  const api = calendarRef.value?.getApi();
  if (api) {
    await loadRange({
      startStr: api.view.activeStart.toISOString(),
      endStr: api.view.activeEnd.toISOString(),
    });
  }
};
</script>

<template>
  <div class="flex w-full h-full overflow-hidden">
    <CalendarSidebarFilters
      v-model:selected-agent-ids="selectedAgentIds"
      v-model:selected-pipeline-ids="selectedPipelineIds"
    />

    <div class="flex flex-col flex-1 overflow-hidden p-6 gap-4">
      <div class="flex items-center justify-between gap-3 flex-wrap">
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('CALENDAR.HEADER') }}
        </h1>
        <div class="flex items-center gap-2">
          <span v-if="uiFlags.isFetching" class="text-xs text-n-slate-11">
            {{ t('CALENDAR.LOADING') }}
          </span>
          <button
            class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600"
            @click="openNewEvent"
          >
            {{ t('CALENDAR.NEW_EVENT') }}
          </button>
        </div>
      </div>

      <div class="flex-1 overflow-hidden calendar-wrap">
        <FullCalendar ref="calendarRef" :options="calendarOptions" />
      </div>
    </div>

    <CalendarEventModal
      v-if="showModal"
      :event="editingEvent"
      :preset-times="presetTimes"
      @close="showModal = false"
      @saved="onSaved"
    />
  </div>
</template>

<style scoped>
/* Escopar overrides para não brigar com o reset do Tailwind. */
.calendar-wrap :deep(.fc) {
  --fc-border-color: var(--color-border-weak, #e5e7eb);
  font-size: 0.85rem;
}
.calendar-wrap :deep(.fc .fc-button-primary) {
  background-color: transparent;
  border-color: var(--fc-border-color);
  color: inherit;
}
.calendar-wrap :deep(.fc .fc-button-primary:not(:disabled).fc-button-active) {
  background-color: #1f93ff;
  border-color: #1f93ff;
  color: #fff;
}
</style>
