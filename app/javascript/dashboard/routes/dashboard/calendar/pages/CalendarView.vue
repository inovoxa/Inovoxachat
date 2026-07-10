<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import listPlugin from '@fullcalendar/list';
import interactionPlugin from '@fullcalendar/interaction';
import allLocales from '@fullcalendar/core/locales-all';
import CalendarEventModal from '../components/CalendarEventModal.vue';
import CalendarSidebarFilters from '../components/CalendarSidebarFilters.vue';

const store = useStore();
const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();

// Locale do FullCalendar acompanha o idioma da UI ('pt_BR' -> 'pt-br').
const calendarLocale = computed(() =>
  (locale.value || 'en').toLowerCase().replace('_', '-')
);

const openSettings = () => {
  router.push({
    name: 'calendar_integrations_index',
    params: { accountId: route.params.accountId },
  });
};

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
  locales: allLocales,
  locale: calendarLocale.value,
  headerToolbar: {
    left: 'prev,next today',
    center: 'title',
    right: 'dayGridMonth,timeGridWeek,timeGridDay,listWeek',
  },
  buttonText: {
    today: t('CALENDAR.VIEWS.TODAY'),
    month: t('CALENDAR.VIEWS.MONTH'),
    week: t('CALENDAR.VIEWS.WEEK'),
    day: t('CALENDAR.VIEWS.DAY'),
    list: t('CALENDAR.VIEWS.AGENDA'),
  },
  noEventsText: t('CALENDAR.NO_EVENTS'),
  allDayText: t('CALENDAR.MODAL.FIELDS.ALL_DAY'),
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
            v-tooltip.bottom="t('CALENDAR.SETTINGS_LINK')"
            class="px-2 py-1.5 rounded-lg border border-n-weak text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-black2"
            @click="openSettings"
          >
            <span class="i-lucide-settings block w-4 h-4" />
          </button>
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
/* Overrides escopados usando os tokens do tema (variam entre claro/escuro),
   para o FullCalendar não impor os fundos brancos padrão no dark mode. */
.calendar-wrap :deep(.fc) {
  --fc-border-color: rgb(var(--slate-6));
  --fc-page-bg-color: rgb(var(--solid-1));
  --fc-neutral-bg-color: rgb(var(--slate-3));
  --fc-neutral-text-color: rgb(var(--slate-11));
  --fc-list-event-hover-bg-color: rgb(var(--slate-3));
  --fc-today-bg-color: rgb(31 147 255 / 0.08);
  color: rgb(var(--slate-12));
  font-size: 0.85rem;
}
.calendar-wrap :deep(.fc .fc-button-primary) {
  background-color: transparent;
  border-color: var(--fc-border-color);
  color: inherit;
  text-transform: capitalize;
}
.calendar-wrap :deep(.fc .fc-button-primary:not(:disabled).fc-button-active),
.calendar-wrap :deep(.fc .fc-button-primary:not(:disabled):active) {
  background-color: #1f93ff;
  border-color: #1f93ff;
  color: #fff;
}
/* Cabeçalho de dia da visão Agenda (list view): fundo e texto do tema. */
.calendar-wrap :deep(.fc .fc-list-day-cushion) {
  background-color: rgb(var(--slate-3));
  color: rgb(var(--slate-12));
}
.calendar-wrap :deep(.fc .fc-list-event:hover td) {
  background-color: rgb(var(--slate-3));
}
.calendar-wrap :deep(.fc .fc-list-empty) {
  background-color: transparent;
  color: rgb(var(--slate-11));
}
/* Cabeçalhos de coluna (Mês/Semana/Dia) também acompanham o tema. */
.calendar-wrap :deep(.fc .fc-col-header-cell-cushion),
.calendar-wrap :deep(.fc .fc-daygrid-day-number),
.calendar-wrap :deep(.fc .fc-list-day-text),
.calendar-wrap :deep(.fc .fc-list-day-side-text) {
  color: rgb(var(--slate-12));
}
</style>
