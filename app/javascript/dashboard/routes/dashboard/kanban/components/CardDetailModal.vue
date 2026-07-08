<script setup>
/* global axios */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { dynamicTime } from 'shared/helpers/timeHelper';

const props = defineProps({
  card: {
    type: Object,
    required: true,
  },
  stages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'schedule', 'moved']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const messages = ref([]);
const loading = ref(false);
const isConversation = computed(() => props.card.type === 'conversation');
const accountId = computed(() => route.params.accountId);

const stripHtml = html => {
  const tmp = document.createElement('div');
  tmp.innerHTML = html || '';
  return tmp.textContent || tmp.innerText || '';
};

const relativeTime = ts => (ts ? dynamicTime(ts) : '');

const loadMessages = async () => {
  if (!isConversation.value) return;
  loading.value = true;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId.value}/conversations/${props.card.id}/messages`
    );
    messages.value = (data.payload || [])
      .filter(m => [0, 1].includes(m.message_type) && !m.private)
      .slice(-30);
  } catch (e) {
    messages.value = [];
  } finally {
    loading.value = false;
  }
};

onMounted(loadMessages);

const openFull = () => {
  if (isConversation.value) {
    router.push(`/app/accounts/${accountId.value}/conversations/${props.card.id}`);
  } else {
    router.push(`/app/accounts/${accountId.value}/contacts/${props.card.id}`);
  }
};

const moveToStage = event => {
  emit('moved', { card: props.card, stageId: Number(event.target.value) });
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-lg rounded-xl bg-n-solid-1 border border-n-weak flex flex-col max-h-[85vh]"
    >
      <div class="flex items-start justify-between gap-3 p-4 border-b border-n-weak">
        <div class="flex items-center gap-3 min-w-0">
          <img
            v-if="card.contact?.thumbnail || card.thumbnail"
            :src="card.contact?.thumbnail || card.thumbnail"
            class="w-10 h-10 rounded-full object-cover"
          />
          <div class="min-w-0">
            <h2 class="text-base font-medium text-n-slate-12 truncate">
              {{ card.contact?.name || card.name }}
            </h2>
            <p class="text-xs text-n-slate-11">
              <span v-if="isConversation">#{{ card.id }} · {{ card.status }}</span>
              <span v-else>{{ card.email || card.phone_number }}</span>
            </p>
          </div>
        </div>
        <button
          class="text-n-slate-11 hover:text-n-slate-12 text-lg leading-none"
          @click="emit('close')"
        >
          ×
        </button>
      </div>

      <div class="flex flex-wrap gap-2 px-4 py-3 border-b border-n-weak text-xs">
        <span
          v-if="card.inbox_name"
          class="px-2 py-0.5 rounded-full bg-n-alpha-black2 text-n-slate-11"
        >
          {{ card.inbox_name }}
        </span>
        <span
          v-if="card.priority"
          class="px-2 py-0.5 rounded-full bg-n-alpha-black2 text-n-slate-11"
        >
          {{ card.priority }}
        </span>
        <span
          v-if="card.assignee"
          class="px-2 py-0.5 rounded-full bg-n-alpha-black2 text-n-slate-11"
        >
          {{ card.assignee.name }}
        </span>
        <span
          v-for="label in card.labels || []"
          :key="label"
          class="px-2 py-0.5 rounded-full bg-n-slate-4 text-n-slate-11"
        >
          {{ label }}
        </span>
        <span
          v-if="card.last_activity_at"
          class="px-2 py-0.5 rounded-full bg-n-alpha-black2 text-n-slate-10 ml-auto"
        >
          {{ relativeTime(card.last_activity_at) }}
        </span>
      </div>

      <div class="flex-1 overflow-y-auto p-4">
        <template v-if="isConversation">
          <p v-if="loading" class="text-sm text-n-slate-11">
            {{ t('KANBAN.CARD_MODAL.LOADING') }}
          </p>
          <p
            v-else-if="!messages.length"
            class="text-sm text-n-slate-10 text-center py-6"
          >
            {{ t('KANBAN.CARD_MODAL.NO_MESSAGES') }}
          </p>
          <div v-else class="flex flex-col gap-2">
            <div
              v-for="message in messages"
              :key="message.id"
              class="flex flex-col gap-0.5 max-w-[85%]"
              :class="message.message_type === 1 ? 'self-end items-end' : 'self-start'"
            >
              <div
                class="rounded-lg px-3 py-2 text-sm"
                :class="
                  message.message_type === 1
                    ? 'bg-woot-500/15 text-n-slate-12'
                    : 'bg-n-alpha-black2 text-n-slate-12'
                "
              >
                {{ stripHtml(message.content) }}
              </div>
              <span class="text-[10px] text-n-slate-10">
                {{ relativeTime(message.created_at) }}
              </span>
            </div>
          </div>
        </template>
        <p v-else class="text-sm text-n-slate-11">
          {{ t('KANBAN.CARD_MODAL.CONTACT_HINT') }}
        </p>
      </div>

      <div class="flex items-center gap-2 p-4 border-t border-n-weak flex-wrap">
        <select
          v-if="stages.length"
          :value="''"
          class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-2 py-1.5 text-n-slate-11"
          @change="moveToStage"
        >
          <option value="" disabled>
            {{ t('KANBAN.CARD_MODAL.MOVE_TO') }}
          </option>
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
        <button
          v-if="isConversation"
          class="text-sm px-3 py-1.5 rounded-lg border border-n-weak text-n-slate-12 hover:bg-n-alpha-black2"
          @click="emit('schedule', card)"
        >
          {{ t('KANBAN.CARD_MODAL.SCHEDULE') }}
        </button>
        <button
          class="text-sm px-3 py-1.5 rounded-lg bg-woot-500 text-white hover:bg-woot-600 ml-auto"
          @click="openFull"
        >
          {{ t('KANBAN.CARD_MODAL.OPEN') }}
        </button>
      </div>
    </div>
  </div>
</template>
