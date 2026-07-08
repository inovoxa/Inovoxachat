<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import PipelineStageColumn from './PipelineStageColumn.vue';
import CardDetailModal from './CardDetailModal.vue';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  loading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['reload', 'schedule']);

const store = useStore();
const { t } = useI18n();

const columns = ref([]);
const error = ref('');
const selectedCard = ref(null);

const stageOptions = computed(() =>
  columns.value.map(column => ({ id: column.id, name: column.name }))
);

// Cards de conversa e de contato convivem na mesma coluna; a chave única
// combina o tipo com o id para o drag-and-drop não confundir os dois.
const buildColumns = () => {
  columns.value = props.stages.map(stage => ({
    id: stage.id,
    name: stage.name,
    color: stage.color,
    items: [
      ...(stage.conversations || []).map(card => ({
        ...card,
        type: 'conversation',
        key: `conversation-${card.id}`,
      })),
      ...(stage.contacts || []).map(card => ({
        ...card,
        type: 'contact',
        key: `contact-${card.id}`,
      })),
    ],
  }));
};

watch(() => props.stages, buildColumns, { immediate: true, deep: true });

const moveCard = async (item, stageId) => {
  error.value = '';
  try {
    if (item.type === 'conversation') {
      await store.dispatch('pipelines/moveConversationToStage', {
        conversationId: item.id,
        stageId,
      });
    } else {
      await store.dispatch('pipelines/moveContactToStage', {
        contactId: item.id,
        stageId,
      });
    }
    return true;
  } catch (e) {
    error.value = t('KANBAN.BOARD.MOVE_ERROR');
    emit('reload');
    return false;
  }
};

// Update otimista: o vuedraggable já moveu o card localmente; se a API
// falhar, recarregamos o board para reverter.
const onChange = (stageId, event) => {
  if (!event.added) return;
  moveCard(event.added.element, stageId);
};

const onCardClick = item => {
  selectedCard.value = item;
};

const onModalMove = async ({ card, stageId }) => {
  const ok = await moveCard(card, stageId);
  selectedCard.value = null;
  if (ok) emit('reload');
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-2">
    <p v-if="error" class="text-red-500 text-sm">{{ error }}</p>
    <p v-if="loading" class="text-xs text-n-slate-11">
      {{ t('KANBAN.LOADING') }}
    </p>
    <div class="flex gap-4 overflow-x-auto h-full pb-2">
      <PipelineStageColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        @change="event => onChange(column.id, event)"
        @card-click="onCardClick"
      />
    </div>

    <CardDetailModal
      v-if="selectedCard"
      :card="selectedCard"
      :stages="stageOptions"
      @close="selectedCard = null"
      @moved="onModalMove"
      @schedule="card => emit('schedule', card)"
    />
  </div>
</template>
