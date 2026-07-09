<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  // Registro existente (edição) ou null (criação).
  event: {
    type: Object,
    default: null,
  },
  // { start: Date, end: Date, allDay } quando aberto por clique num horário.
  presetTimes: {
    type: Object,
    default: null,
  },
  // Pré-vínculos ao abrir a partir de uma conversa (ver CalendarConversationAction).
  preselectedConversationId: {
    type: [Number, String],
    default: null,
  },
  preselectedContactId: {
    type: [Number, String],
    default: null,
  },
  preselectedPipelineStageId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const store = useStore();
const { t } = useI18n();

const pipelines = useMapGetter('pipelines/getPipelines');
const uiFlags = useMapGetter('calendarEvents/getUIFlags');

const isEdit = computed(() => !!props.event?.id);
const isRecurringSeries = computed(() => !!props.event?.recurrence_rule);
const isExternal = computed(
  () => !!props.event && props.event.source !== 'internal'
);

const RECURRENCE_PRESETS = {
  NONE: '',
  DAILY: 'FREQ=DAILY',
  WEEKLY: 'FREQ=WEEKLY',
  MONTHLY: 'FREQ=MONTHLY',
};

const browserTz =
  Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

// --- helpers de data (ISO <-> datetime-local no fuso do browser) ---
const toLocalInput = value => {
  if (!value) return '';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};
const toISO = localValue => {
  if (!localValue) return null;
  const d = new Date(localValue);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
};

const detectPreset = rule => {
  if (!rule) return 'NONE';
  const match = Object.entries(RECURRENCE_PRESETS).find(
    ([, value]) => value && value === rule
  );
  return match ? match[0] : 'CUSTOM';
};

const form = reactive({
  title: '',
  description: '',
  location: '',
  startLocal: '',
  endLocal: '',
  allDay: false,
  timezone: browserTz,
  status: 'confirmed',
  recurrencePreset: 'NONE',
  recurrenceCustom: '',
  pipelineId: null,
  pipelineStageId: null,
});

const attendees = ref([]);
const error = ref('');

const stagesForPipeline = computed(() => {
  const pipeline = pipelines.value.find(p => p.id === form.pipelineId);
  return pipeline ? pipeline.stages : [];
});

onMounted(() => {
  if (!pipelines.value.length) store.dispatch('pipelines/get');

  if (props.event) {
    form.title = props.event.title || '';
    form.description = props.event.description || '';
    form.location = props.event.location || '';
    form.startLocal = toLocalInput(props.event.start_time);
    form.endLocal = toLocalInput(props.event.end_time);
    form.allDay = !!props.event.all_day;
    form.timezone = props.event.timezone || browserTz;
    form.status = props.event.status || 'confirmed';
    form.recurrencePreset = detectPreset(props.event.recurrence_rule);
    form.recurrenceCustom =
      form.recurrencePreset === 'CUSTOM' ? props.event.recurrence_rule : '';
    form.pipelineStageId = props.event.pipeline_stage?.id || null;
    form.pipelineId = props.event.pipeline_stage?.pipeline?.id || null;
    attendees.value = (props.event.attendees || []).map(a => ({
      id: a.id,
      email: a.email,
      name: a.name,
    }));
  } else if (props.presetTimes) {
    form.startLocal = toLocalInput(props.presetTimes.start);
    form.endLocal = toLocalInput(props.presetTimes.end);
    form.allDay = !!props.presetTimes.allDay;
    form.pipelineStageId = props.preselectedPipelineStageId || null;
  } else {
    const now = new Date();
    const later = new Date(now.getTime() + 60 * 60 * 1000);
    form.startLocal = toLocalInput(now);
    form.endLocal = toLocalInput(later);
    form.pipelineStageId = props.preselectedPipelineStageId || null;
  }
});

const addAttendee = () => {
  attendees.value.push({ email: '', name: '' });
};
const removeAttendee = index => {
  attendees.value.splice(index, 1);
};

const resolvedRecurrenceRule = () => {
  if (form.recurrencePreset === 'NONE') return null;
  if (form.recurrencePreset === 'CUSTOM') {
    return form.recurrenceCustom.trim() || null;
  }
  return RECURRENCE_PRESETS[form.recurrencePreset];
};

const buildPayload = () => {
  const payload = {
    title: form.title.trim(),
    description: form.description,
    location: form.location,
    start_time: toISO(form.startLocal),
    end_time: toISO(form.endLocal),
    all_day: form.allDay,
    timezone: form.timezone,
    status: form.status,
    recurrence_rule: resolvedRecurrenceRule(),
    pipeline_stage_id: form.pipelineStageId,
  };

  if (!isEdit.value) {
    payload.conversation_id = props.preselectedConversationId;
    payload.contact_id = props.preselectedContactId;
  }

  payload.attendees_attributes = attendees.value
    .filter(a => a.email && a.email.trim())
    .map(a => ({ id: a.id, email: a.email.trim(), name: a.name }));

  return payload;
};

const validate = () => {
  if (!form.title.trim() || !form.startLocal || !form.endLocal) {
    error.value = t('CALENDAR.MODAL.REQUIRED_ERROR');
    return false;
  }
  if (new Date(form.endLocal) <= new Date(form.startLocal)) {
    error.value = t('CALENDAR.MODAL.END_BEFORE_START_ERROR');
    return false;
  }
  return true;
};

const onSave = async () => {
  error.value = '';
  if (isExternal.value) return;
  if (!validate()) return;

  try {
    const payload = buildPayload();
    if (isEdit.value) {
      await store.dispatch('calendarEvents/update', {
        id: props.event.id,
        ...payload,
      });
    } else {
      await store.dispatch('calendarEvents/create', payload);
    }
    useAlert(t('CALENDAR.MODAL.SAVED'));
    emit('saved');
  } catch (e) {
    error.value = e?.message || t('CALENDAR.MODAL.ERROR');
  }
};

const onDelete = async () => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CALENDAR.MODAL.DELETE_CONFIRM'))) return;
  try {
    await store.dispatch('calendarEvents/delete', props.event.id);
    useAlert(t('CALENDAR.MODAL.DELETED'));
    emit('saved');
  } catch (e) {
    error.value = e?.message || t('CALENDAR.MODAL.ERROR');
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-lg rounded-xl bg-n-solid-1 border border-n-weak p-5 flex flex-col gap-4 max-h-[88vh] overflow-y-auto"
    >
      <div class="flex items-start justify-between gap-2">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ isEdit ? t('CALENDAR.MODAL.EDIT_TITLE') : t('CALENDAR.MODAL.NEW_TITLE') }}
        </h2>
        <button
          class="text-n-slate-11 hover:text-n-slate-12 text-lg leading-none"
          @click="emit('close')"
        >
          ×
        </button>
      </div>

      <p
        v-if="isExternal"
        class="text-xs rounded-lg bg-n-alpha-black2 px-3 py-2 text-n-slate-11"
      >
        {{ t('CALENDAR.MODAL.EXTERNAL_NOTICE', { source: event.source }) }}
      </p>
      <p
        v-else-if="isRecurringSeries"
        class="text-xs rounded-lg bg-n-alpha-black2 px-3 py-2 text-n-slate-11"
      >
        {{ t('CALENDAR.MODAL.SERIES_NOTICE') }}
      </p>

      <fieldset :disabled="isExternal" class="flex flex-col gap-4">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('CALENDAR.MODAL.FIELDS.TITLE') }}
          <input
            v-model="form.title"
            type="text"
            :placeholder="t('CALENDAR.MODAL.FIELDS.TITLE_PLACEHOLDER')"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
          />
        </label>

        <div class="grid grid-cols-2 gap-3">
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.START') }}
            <input
              v-model="form.startLocal"
              type="datetime-local"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.END') }}
            <input
              v-model="form.endLocal"
              type="datetime-local"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            />
          </label>
        </div>

        <div class="flex items-center gap-4">
          <label class="flex items-center gap-2 text-sm text-n-slate-11">
            <input v-model="form.allDay" type="checkbox" />
            {{ t('CALENDAR.MODAL.FIELDS.ALL_DAY') }}
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-11 flex-1">
            {{ t('CALENDAR.MODAL.FIELDS.STATUS') }}
            <select
              v-model="form.status"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            >
              <option value="confirmed">{{ t('CALENDAR.MODAL.STATUS.CONFIRMED') }}</option>
              <option value="tentative">{{ t('CALENDAR.MODAL.STATUS.TENTATIVE') }}</option>
              <option value="cancelled">{{ t('CALENDAR.MODAL.STATUS.CANCELLED') }}</option>
            </select>
          </label>
        </div>

        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('CALENDAR.MODAL.FIELDS.LOCATION') }}
          <input
            v-model="form.location"
            type="text"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
          />
        </label>

        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('CALENDAR.MODAL.FIELDS.DESCRIPTION') }}
          <textarea
            v-model="form.description"
            rows="2"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 resize-none"
          />
        </label>

        <div class="grid grid-cols-2 gap-3">
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.RECURRENCE') }}
            <select
              v-model="form.recurrencePreset"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            >
              <option value="NONE">{{ t('CALENDAR.MODAL.RECURRENCE_PRESETS.NONE') }}</option>
              <option value="DAILY">{{ t('CALENDAR.MODAL.RECURRENCE_PRESETS.DAILY') }}</option>
              <option value="WEEKLY">{{ t('CALENDAR.MODAL.RECURRENCE_PRESETS.WEEKLY') }}</option>
              <option value="MONTHLY">{{ t('CALENDAR.MODAL.RECURRENCE_PRESETS.MONTHLY') }}</option>
              <option value="CUSTOM">{{ t('CALENDAR.MODAL.RECURRENCE_PRESETS.CUSTOM') }}</option>
            </select>
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.TIMEZONE') }}
            <input
              v-model="form.timezone"
              type="text"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            />
          </label>
        </div>

        <label
          v-if="form.recurrencePreset === 'CUSTOM'"
          class="flex flex-col gap-1 text-sm text-n-slate-11"
        >
          RRULE
          <input
            v-model="form.recurrenceCustom"
            type="text"
            :placeholder="t('CALENDAR.MODAL.RRULE_PLACEHOLDER')"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 font-mono"
          />
        </label>

        <div class="grid grid-cols-2 gap-3">
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.PIPELINE') }}
            <select
              v-model="form.pipelineId"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
              @change="form.pipelineStageId = null"
            >
              <option :value="null">—</option>
              <option v-for="p in pipelines" :key="p.id" :value="p.id">
                {{ p.name }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1 text-sm text-n-slate-11">
            {{ t('CALENDAR.MODAL.FIELDS.STAGE') }}
            <select
              v-model="form.pipelineStageId"
              :disabled="!form.pipelineId"
              class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 disabled:opacity-50"
            >
              <option :value="null">—</option>
              <option v-for="s in stagesForPipeline" :key="s.id" :value="s.id">
                {{ s.name }}
              </option>
            </select>
          </label>
        </div>

        <div class="flex flex-col gap-2">
          <div class="flex items-center justify-between">
            <span class="text-sm text-n-slate-11">
              {{ t('CALENDAR.MODAL.FIELDS.ATTENDEES') }}
            </span>
            <button
              type="button"
              class="text-xs text-woot-500 hover:underline"
              @click="addAttendee"
            >
              {{ t('CALENDAR.MODAL.FIELDS.ADD_ATTENDEE') }}
            </button>
          </div>
          <div
            v-for="(attendee, index) in attendees"
            :key="index"
            class="flex items-center gap-2"
          >
            <input
              v-model="attendee.email"
              type="email"
              :placeholder="t('CALENDAR.MODAL.FIELDS.ATTENDEE_EMAIL')"
              class="flex-1 text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            />
            <input
              v-model="attendee.name"
              type="text"
              :placeholder="t('CALENDAR.MODAL.FIELDS.ATTENDEE_NAME')"
              class="flex-1 text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            />
            <button
              type="button"
              class="text-n-slate-10 hover:text-red-500 text-lg leading-none"
              @click="removeAttendee(index)"
            >
              ×
            </button>
          </div>
        </div>
      </fieldset>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <div class="flex items-center justify-between gap-2 pt-1">
        <button
          v-if="isEdit && !isExternal"
          class="px-3 py-2 text-sm rounded-lg text-red-500 hover:bg-red-50"
          :disabled="uiFlags.isDeleting"
          @click="onDelete"
        >
          {{ t('CALENDAR.MODAL.DELETE') }}
        </button>
        <div class="flex items-center gap-2 ml-auto">
          <button
            class="px-3 py-2 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
            @click="emit('close')"
          >
            {{ t('CALENDAR.MODAL.CANCEL') }}
          </button>
          <button
            v-if="!isExternal"
            class="px-3 py-2 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
            :disabled="uiFlags.isCreating || uiFlags.isUpdating"
            @click="onSave"
          >
            {{ t('CALENDAR.MODAL.SAVE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
