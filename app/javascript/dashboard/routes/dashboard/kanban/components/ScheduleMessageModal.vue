<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ScheduledMessagesAPI from 'dashboard/api/scheduledMessages';
import { dynamicTime, messageTimestamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  title: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const scheduled = ref([]);
const content = ref('');
const scheduledAt = ref('');
const loading = ref(false);
const saving = ref(false);
const error = ref('');

const STATUS_CLASS = {
  pending: 'text-woot-500',
  sent: 'text-green-500',
  canceled: 'text-n-slate-10',
  failed: 'text-red-500',
};

// Mínimo do input: agora + 1 minuto, no formato datetime-local.
const minDateTime = computed(() => {
  const d = new Date(Date.now() + 60000);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
});

const load = async () => {
  loading.value = true;
  try {
    const { data } = await ScheduledMessagesAPI.get(props.conversationId);
    scheduled.value = data.payload || [];
  } catch (e) {
    scheduled.value = [];
  } finally {
    loading.value = false;
  }
};

onMounted(load);

const relativeTime = ts => (ts ? dynamicTime(ts) : '');
const absoluteTime = ts => (ts ? messageTimestamp(ts, 'MMM d, yyyy · h:mm a') : '');

const onSubmit = async () => {
  if (!content.value.trim() || !scheduledAt.value) return;
  const when = new Date(scheduledAt.value);
  if (Number.isNaN(when.getTime()) || when <= new Date()) {
    error.value = t('KANBAN.SCHEDULE_MODAL.PAST_ERROR');
    return;
  }
  saving.value = true;
  error.value = '';
  try {
    await ScheduledMessagesAPI.create(props.conversationId, {
      content: content.value.trim(),
      scheduled_at: when.toISOString(),
    });
    content.value = '';
    scheduledAt.value = '';
    await load();
  } catch (e) {
    error.value = e?.response?.data?.message || t('KANBAN.SCHEDULE_MODAL.ERROR');
  } finally {
    saving.value = false;
  }
};

const onCancel = async id => {
  try {
    await ScheduledMessagesAPI.delete(props.conversationId, id);
    await load();
  } catch (e) {
    error.value = t('KANBAN.SCHEDULE_MODAL.ERROR');
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-md rounded-xl bg-n-solid-1 border border-n-weak p-5 flex flex-col gap-4 max-h-[85vh] overflow-y-auto"
    >
      <div class="flex items-start justify-between gap-2">
        <h2 class="text-lg font-medium text-n-slate-12">
          {{ t('KANBAN.SCHEDULE_MODAL.TITLE') }}
        </h2>
        <button
          class="text-n-slate-11 hover:text-n-slate-12 text-lg leading-none"
          @click="emit('close')"
        >
          ×
        </button>
      </div>
      <p v-if="title" class="text-xs text-n-slate-11 -mt-2">{{ title }}</p>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SCHEDULE_MODAL.MESSAGE_LABEL') }}
        <textarea
          v-model="content"
          rows="3"
          :placeholder="t('KANBAN.SCHEDULE_MODAL.MESSAGE_PLACEHOLDER')"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 resize-none"
        />
      </label>

      <label class="flex flex-col gap-1 text-sm text-n-slate-11">
        {{ t('KANBAN.SCHEDULE_MODAL.WHEN_LABEL') }}
        <input
          v-model="scheduledAt"
          type="datetime-local"
          :min="minDateTime"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12"
        />
      </label>

      <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>

      <button
        class="px-3 py-2 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
        :disabled="saving || !content.trim() || !scheduledAt"
        @click="onSubmit"
      >
        {{ t('KANBAN.SCHEDULE_MODAL.SUBMIT') }}
      </button>

      <div class="border-t border-n-weak pt-3 flex flex-col gap-2">
        <span class="text-sm text-n-slate-11">
          {{ t('KANBAN.SCHEDULE_MODAL.LIST_LABEL') }}
        </span>
        <p v-if="loading" class="text-xs text-n-slate-10">
          {{ t('KANBAN.SCHEDULE_MODAL.LOADING') }}
        </p>
        <p
          v-else-if="!scheduled.length"
          class="text-xs text-n-slate-10 text-center py-3"
        >
          {{ t('KANBAN.SCHEDULE_MODAL.EMPTY') }}
        </p>
        <div
          v-for="item in scheduled"
          :key="item.id"
          class="rounded-lg border border-n-weak bg-n-alpha-black2 p-2.5 flex flex-col gap-1"
        >
          <p class="text-sm text-n-slate-12">{{ item.content }}</p>
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-xs"
              :class="STATUS_CLASS[item.status]"
              :title="absoluteTime(item.scheduled_at)"
            >
              {{ t(`KANBAN.SCHEDULE_MODAL.STATUS.${item.status.toUpperCase()}`) }}
              · {{ relativeTime(item.scheduled_at) }}
            </span>
            <button
              v-if="item.status === 'pending'"
              class="text-xs text-red-500 hover:underline"
              @click="onCancel(item.id)"
            >
              {{ t('KANBAN.SCHEDULE_MODAL.CANCEL') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
