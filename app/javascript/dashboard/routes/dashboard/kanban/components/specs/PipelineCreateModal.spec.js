import { mount, flushPromises } from '@vue/test-utils';
import PipelineCreateModal from '../PipelineCreateModal.vue';

const mocks = vi.hoisted(() => ({
  dispatch: vi.fn(() => Promise.resolve({})),
}));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useStore: () => ({ dispatch: mocks.dispatch }),
    useMapGetter: key => {
      if (key === 'pipelines/getTemplates') {
        return ref([
          {
            key: 'vendas',
            label: 'Vendas',
            stages: [
              { name: 'Lead', color: '#1F93FF' },
              { name: 'Proposta', color: '#F59E0B' },
            ],
          },
        ]);
      }
      return ref({ isCreating: false });
    },
  };
});

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('PipelineCreateModal', () => {
  beforeEach(() => {
    mocks.dispatch.mockClear();
    mocks.dispatch.mockResolvedValue({});
  });

  const mountModal = () => mount(PipelineCreateModal);

  const findSubmitButton = wrapper =>
    wrapper
      .findAll('button')
      .find(button => button.text() === 'KANBAN.CREATE_MODAL.SUBMIT');

  const findTemplateButton = wrapper =>
    wrapper.findAll('button').find(button => button.text().includes('Vendas'));

  it('fetches the templates on mount', () => {
    mountModal();

    expect(mocks.dispatch).toHaveBeenCalledWith('pipelines/fetchTemplates');
  });

  it('renders the template cards and the custom option', () => {
    const wrapper = mountModal();

    expect(findTemplateButton(wrapper)).toBeTruthy();
    expect(wrapper.text()).toContain('KANBAN.CREATE_MODAL.CUSTOM_LABEL');
  });

  it('shows the stage preview of the selected template', async () => {
    const wrapper = mountModal();

    await findTemplateButton(wrapper).trigger('click');

    expect(wrapper.text()).toContain('Lead');
    expect(wrapper.text()).toContain('Proposta');
    expect(wrapper.text()).toContain('KANBAN.CREATE_MODAL.PREVIEW_HINT');
  });

  it('disables the submit button without a name', () => {
    const wrapper = mountModal();

    expect(findSubmitButton(wrapper).attributes('disabled')).toBeDefined();
  });

  it('creates a pipeline with the selected template and emits created', async () => {
    const wrapper = mountModal();

    await wrapper.find('input[type="text"]').setValue('Meu funil');
    await findTemplateButton(wrapper).trigger('click');
    await findSubmitButton(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('pipelines/create', {
      name: 'Meu funil',
      description: '',
      template_key: 'vendas',
      auto_add_mode: 'disabled',
    });
    expect(wrapper.emitted('created')).toBeTruthy();
  });

  it('creates a custom pipeline with a null template_key', async () => {
    const wrapper = mountModal();

    await wrapper.find('input[type="text"]').setValue('Do zero');
    await findSubmitButton(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('pipelines/create', {
      name: 'Do zero',
      description: '',
      template_key: null,
      auto_add_mode: 'disabled',
    });
  });
});
