<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  page: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const store = useStore();
const { t } = useI18n();

const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');
const pipelines = useMapGetter('pipelines/getPipelines');
const uiFlags = useMapGetter('bookingPages/getUIFlags');

const isEdit = computed(() => !!props.page?.id);
const error = ref('');

const WEEKDAYS = [
  { dow: 0, label: 'DOM' },
  { dow: 1, label: 'SEG' },
  { dow: 2, label: 'TER' },
  { dow: 3, label: 'QUA' },
  { dow: 4, label: 'QUI' },
  { dow: 5, label: 'SEX' },
  { dow: 6, label: 'SAB' },
];

const browserTz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

const form = reactive({
  name: '',
  description: '',
  duration_minutes: 30,
  buffer_before_minutes: 0,
  buffer_after_minutes: 0,
  min_notice_hours: 4,
  max_advance_days: 30,
  timezone: browserTz,
  active: true,
  inbox_id: null,
  user_id: null,
  pipeline_id: null,
  default_pipeline_stage_id: null,
});

// Grade semanal: cada dia tem uma lista de faixas { id?, start, end }.
const days = reactive(WEEKDAYS.map(d => ({ ...d, ranges: [] })));
const removedAvailabilityIds = ref([]);

const stagesForPipeline = computed(() => {
  const pipeline = pipelines.value.find(p => p.id === form.pipeline_id);
  return pipeline ? pipeline.stages : [];
});

onMounted(() => {
  if (!inboxes.value.length) store.dispatch('inboxes/get');
  if (!agents.value.length) store.dispatch('agents/get');
  if (!pipelines.value.length) store.dispatch('pipelines/get');

  if (props.page) {
    Object.assign(form, {
      name: props.page.name,
      description: props.page.description,
      duration_minutes: props.page.duration_minutes,
      buffer_before_minutes: props.page.buffer_before_minutes,
      buffer_after_minutes: props.page.buffer_after_minutes,
      min_notice_hours: props.page.min_notice_hours,
      max_advance_days: props.page.max_advance_days,
      timezone: props.page.timezone,
      active: props.page.active,
      inbox_id: props.page.inbox_id,
      user_id: props.page.user_id,
      default_pipeline_stage_id: props.page.default_pipeline_stage_id,
    });
    // Descobre o pipeline a partir do estágio padrão.
    if (props.page.default_pipeline_stage_id) {
      const pipeline = pipelines.value.find(p =>
        (p.stages || []).some(
          s => s.id === props.page.default_pipeline_stage_id
        )
      );
      form.pipeline_id = pipeline?.id || null;
    }
    (props.page.availabilities || []).forEach(a => {
      const day = days.find(d => d.dow === a.day_of_week);
      if (day) day.ranges.push({ id: a.id, start: a.start_time, end: a.end_time });
    });
  }
});

const addRange = day => {
  day.ranges.push({ start: '09:00', end: '17:00' });
};

const removeRange = (day, index) => {
  const [removed] = day.ranges.splice(index, 1);
  if (removed?.id) removedAvailabilityIds.value.push(removed.id);
};

const buildAvailabilitiesAttributes = () => {
  const attributes = [];
  days.forEach(day => {
    day.ranges.forEach(range => {
      if (!range.start || !range.end) return;
      attributes.push({
        id: range.id,
        day_of_week: day.dow,
        start_time: range.start,
        end_time: range.end,
      });
    });
  });
  removedAvailabilityIds.value.forEach(id => {
    attributes.push({ id, _destroy: true });
  });
  return attributes;
};

const validate = () => {
  if (!form.name.trim()) {
    error.value = t('BOOKING.FORM.NAME_REQUIRED');
    return false;
  }
  if (!form.inbox_id) {
    error.value = t('BOOKING.FORM.INBOX_REQUIRED');
    return false;
  }
  if (!form.user_id) {
    error.value = t('BOOKING.FORM.OWNER_REQUIRED');
    return false;
  }
  return true;
};

const save = async () => {
  error.value = '';
  if (!validate()) return;

  const payload = {
    name: form.name.trim(),
    description: form.description,
    duration_minutes: Number(form.duration_minutes),
    buffer_before_minutes: Number(form.buffer_before_minutes),
    buffer_after_minutes: Number(form.buffer_after_minutes),
    min_notice_hours: Number(form.min_notice_hours),
    max_advance_days: Number(form.max_advance_days),
    timezone: form.timezone,
    active: form.active,
    inbox_id: form.inbox_id,
    user_id: form.user_id,
    default_pipeline_stage_id: form.default_pipeline_stage_id,
    availabilities_attributes: buildAvailabilitiesAttributes(),
  };

  try {
    if (isEdit.value) {
      await store.dispatch('bookingPages/update', { id: props.page.id, ...payload });
    } else {
      await store.dispatch('bookingPages/create', payload);
    }
    emit('saved');
  } catch (e) {
    error.value = e?.message || t('BOOKING.ERROR');
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-2xl rounded-xl bg-n-solid-1 border border-n-weak p-5 flex flex-col gap-4 max-h-[90vh] overflow-y-auto"
    >
      <div class="flex items-start justify-between gap-2">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ isEdit ? t('BOOKING.FORM.EDIT_TITLE') : t('BOOKING.FORM.NEW_TITLE') }}
        </h2>
        <button
          class="text-n-slate-11 hover:text-n-slate-12 text-lg leading-none"
          @click="emit('close')"
        >
          ×
        </button>
      </div>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('BOOKING.FORM.NAME') }}
        <input
          v-model="form.name"
          type="text"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('BOOKING.FORM.DESCRIPTION') }}
        <textarea
          v-model="form.description"
          rows="2"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 resize-none"
        />
      </label>

      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.INBOX') }}
          <select
            v-model="form.inbox_id"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
          >
            <option :value="null">—</option>
            <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
              {{ inbox.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.OWNER') }}
          <select
            v-model="form.user_id"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
          >
            <option :value="null">—</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.DURATION') }}
          <input v-model="form.duration_minutes" type="number" min="1" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.BUFFER_BEFORE') }}
          <input v-model="form.buffer_before_minutes" type="number" min="0" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.BUFFER_AFTER') }}
          <input v-model="form.buffer_after_minutes" type="number" min="0" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.MIN_NOTICE') }}
          <input v-model="form.min_notice_hours" type="number" min="0" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.MAX_ADVANCE') }}
          <input v-model="form.max_advance_days" type="number" min="1" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.TIMEZONE') }}
          <input v-model="form.timezone" type="text" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12" />
        </label>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.PIPELINE') }}
          <select
            v-model="form.pipeline_id"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
            @change="form.default_pipeline_stage_id = null"
          >
            <option :value="null">—</option>
            <option v-for="p in pipelines" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t('BOOKING.FORM.STAGE') }}
          <select
            v-model="form.default_pipeline_stage_id"
            :disabled="!form.pipeline_id"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 disabled:opacity-50"
          >
            <option :value="null">—</option>
            <option v-for="s in stagesForPipeline" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </label>
      </div>

      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        <input v-model="form.active" type="checkbox" />
        {{ t('BOOKING.FORM.ACTIVE') }}
      </label>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('BOOKING.FORM.AVAILABILITY') }}
        </span>
        <div
          v-for="day in days"
          :key="day.dow"
          class="flex items-start gap-3 border-b border-n-weak pb-2"
        >
          <span class="w-10 text-xs font-medium text-n-slate-11 pt-2">
            {{ day.label }}
          </span>
          <div class="flex-1 flex flex-col gap-1.5">
            <div
              v-for="(range, index) in day.ranges"
              :key="index"
              class="flex items-center gap-2"
            >
              <input v-model="range.start" type="time" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1 text-n-slate-12" />
              <span class="text-n-slate-10">–</span>
              <input v-model="range.end" type="time" class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1 text-n-slate-12" />
              <button class="text-n-slate-10 hover:text-red-500 text-lg leading-none" @click="removeRange(day, index)">×</button>
            </div>
            <button class="text-xs text-woot-500 hover:underline self-start" @click="addRange(day)">
              + {{ t('BOOKING.FORM.ADD_RANGE') }}
            </button>
          </div>
        </div>
      </div>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <div class="flex items-center justify-end gap-2 pt-1">
        <button
          class="px-3 py-2 text-sm rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
          @click="emit('close')"
        >
          {{ t('BOOKING.FORM.CANCEL') }}
        </button>
        <button
          class="px-3 py-2 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
          :disabled="uiFlags.isCreating || uiFlags.isUpdating"
          @click="save"
        >
          {{ t('BOOKING.FORM.SAVE') }}
        </button>
      </div>
    </div>
  </div>
</template>
