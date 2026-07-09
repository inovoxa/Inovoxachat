<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarEventModal from 'dashboard/routes/dashboard/calendar/components/CalendarEventModal.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  contactId: {
    type: [Number, String],
    default: null,
  },
  pipelineStageId: {
    type: [Number, String],
    default: null,
  },
});

const { t } = useI18n();

const showModal = ref(false);

// Pré-preenche o horário com a próxima hora cheia para agilizar o agendamento.
const presetTimes = () => {
  const start = new Date();
  start.setMinutes(0, 0, 0);
  start.setHours(start.getHours() + 1);
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  return { start, end, allDay: false };
};

const preset = ref(presetTimes());

const openModal = () => {
  preset.value = presetTimes();
  showModal.value = true;
};
</script>

<template>
  <div>
    <woot-button
      v-tooltip.bottom="t('CALENDAR.CONVERSATION_ACTION.SCHEDULE')"
      variant="smooth"
      size="small"
      color-scheme="secondary"
      icon="i-lucide-calendar-plus"
      @click="openModal"
    />

    <CalendarEventModal
      v-if="showModal"
      :preset-times="preset"
      :preselected-conversation-id="conversationId"
      :preselected-contact-id="contactId"
      :preselected-pipeline-stage-id="pipelineStageId"
      @close="showModal = false"
      @saved="showModal = false"
    />
  </div>
</template>
