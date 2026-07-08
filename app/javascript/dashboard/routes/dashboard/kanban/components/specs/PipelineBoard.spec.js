import { mount, flushPromises } from '@vue/test-utils';
import PipelineBoard from '../PipelineBoard.vue';
import PipelineStageColumn from '../PipelineStageColumn.vue';

const mocks = vi.hoisted(() => ({
  dispatch: vi.fn(() => Promise.resolve({})),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const CardDetailModalStub = {
  name: 'CardDetailModal',
  props: ['card', 'stages'],
  template: '<div class="card-detail-modal">{{ card.id }}</div>',
};

const stages = [
  {
    id: 10,
    name: 'Novo',
    color: '#1F93FF',
    position: 1,
    total_count: 2,
    conversations: [
      { id: 5, status: 'open', priority: null, contact: { name: 'Maria' } },
    ],
    contacts: [{ id: 7, name: 'João', email: 'joao@example.com' }],
  },
  {
    id: 11,
    name: 'Fechado',
    color: '#64748B',
    position: 2,
    total_count: 0,
    conversations: [],
    contacts: [],
  },
];

const mountBoard = () =>
  mount(PipelineBoard, {
    props: { stages },
    global: {
      stubs: {
        CardDetailModal: CardDetailModalStub,
        Draggable: {
          props: ['list'],
          template: `
            <div>
              <template v-for="element in list" :key="element.key">
                <slot name="item" :element="element" />
              </template>
            </div>
          `,
        },
      },
    },
  });

describe('PipelineBoard', () => {
  beforeEach(() => {
    mocks.dispatch.mockClear();
    mocks.dispatch.mockResolvedValue({});
  });

  it('renders one column per stage with conversation and contact cards', () => {
    const wrapper = mountBoard();
    const columns = wrapper.findAllComponents(PipelineStageColumn);

    expect(columns).toHaveLength(2);
    expect(wrapper.text()).toContain('Novo');
    expect(wrapper.text()).toContain('Maria');
    expect(wrapper.text()).toContain('João');
    expect(wrapper.text()).toContain('KANBAN.BOARD.NEW_CONTACT');
  });

  it('shows the card count on the column header', () => {
    const wrapper = mountBoard();
    const firstColumn = wrapper.findAllComponents(PipelineStageColumn).at(0);

    expect(firstColumn.text()).toContain('2');
  });

  it('moves a conversation card to another stage via the API', async () => {
    const wrapper = mountBoard();
    const targetColumn = wrapper.findAllComponents(PipelineStageColumn).at(1);

    targetColumn.vm.$emit('change', {
      added: { element: { type: 'conversation', id: 5 } },
    });
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith(
      'pipelines/moveConversationToStage',
      { conversationId: 5, stageId: 11 }
    );
  });

  it('moves a contact card to another stage via the API', async () => {
    const wrapper = mountBoard();
    const targetColumn = wrapper.findAllComponents(PipelineStageColumn).at(1);

    targetColumn.vm.$emit('change', {
      added: { element: { type: 'contact', id: 7 } },
    });
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('pipelines/moveContactToStage', {
      contactId: 7,
      stageId: 11,
    });
  });

  it('reloads the board and shows an error when the move fails', async () => {
    mocks.dispatch.mockRejectedValueOnce(new Error('boom'));
    const wrapper = mountBoard();
    const targetColumn = wrapper.findAllComponents(PipelineStageColumn).at(1);

    targetColumn.vm.$emit('change', {
      added: { element: { type: 'conversation', id: 5 } },
    });
    await flushPromises();

    expect(wrapper.emitted('reload')).toBeTruthy();
    expect(wrapper.text()).toContain('KANBAN.BOARD.MOVE_ERROR');
  });

  it('opens the detail modal when a card is clicked', async () => {
    const wrapper = mountBoard();
    const firstColumn = wrapper.findAllComponents(PipelineStageColumn).at(0);

    expect(wrapper.find('.card-detail-modal').exists()).toBe(false);

    firstColumn.vm.$emit('cardClick', { type: 'conversation', id: 5 });
    await flushPromises();

    expect(wrapper.find('.card-detail-modal').exists()).toBe(true);
  });

  it('re-emits schedule from the modal', async () => {
    const wrapper = mountBoard();
    const firstColumn = wrapper.findAllComponents(PipelineStageColumn).at(0);
    firstColumn.vm.$emit('cardClick', { type: 'conversation', id: 5 });
    await flushPromises();

    wrapper.findComponent(CardDetailModalStub).vm.$emit('schedule', { id: 5 });

    expect(wrapper.emitted('schedule')).toBeTruthy();
  });
});
