import { mount, flushPromises } from '@vue/test-utils';
import CalendarEventModal from '../CalendarEventModal.vue';

const mocks = vi.hoisted(() => ({
  dispatch: vi.fn(() => Promise.resolve({})),
}));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useStore: () => ({ dispatch: mocks.dispatch }),
    useMapGetter: getter =>
      getter === 'pipelines/getPipelines'
        ? ref([])
        : ref({ isCreating: false, isUpdating: false, isDeleting: false }),
  };
});

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const findButtonByText = (wrapper, text) =>
  wrapper.findAll('button').find(button => button.text() === text);

describe('CalendarEventModal', () => {
  beforeEach(() => {
    mocks.dispatch.mockClear();
    mocks.dispatch.mockResolvedValue({});
  });

  it('renders the create title for a new event', () => {
    const wrapper = mount(CalendarEventModal, { props: { event: null } });
    expect(wrapper.text()).toContain('CALENDAR.MODAL.NEW_TITLE');
  });

  it('dispatches create with the typed values on save', async () => {
    const wrapper = mount(CalendarEventModal, { props: { event: null } });

    await wrapper.find('input[type="text"]').setValue('Reunião');
    const dateInputs = wrapper.findAll('input[type="datetime-local"]');
    await dateInputs[0].setValue('2026-07-10T10:00');
    await dateInputs[1].setValue('2026-07-10T11:00');

    await findButtonByText(wrapper, 'CALENDAR.MODAL.SAVE').trigger('click');
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith(
      'calendarEvents/create',
      expect.objectContaining({ title: 'Reunião' })
    );
    expect(wrapper.emitted('saved')).toBeTruthy();
  });

  it('shows a validation error and does not dispatch when title is empty', async () => {
    const wrapper = mount(CalendarEventModal, { props: { event: null } });

    const dateInputs = wrapper.findAll('input[type="datetime-local"]');
    await dateInputs[0].setValue('2026-07-10T10:00');
    await dateInputs[1].setValue('2026-07-10T11:00');

    await findButtonByText(wrapper, 'CALENDAR.MODAL.SAVE').trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('CALENDAR.MODAL.REQUIRED_ERROR');
    expect(mocks.dispatch).not.toHaveBeenCalledWith(
      'calendarEvents/create',
      expect.anything()
    );
  });

  it('renders external events as read-only without a save button', () => {
    const wrapper = mount(CalendarEventModal, {
      props: {
        event: {
          id: 1,
          title: 'Do Google',
          source: 'google',
          start_time: '2026-07-10T10:00:00Z',
          end_time: '2026-07-10T11:00:00Z',
          attendees: [],
        },
      },
    });

    expect(wrapper.text()).toContain('CALENDAR.MODAL.EXTERNAL_NOTICE');
    expect(findButtonByText(wrapper, 'CALENDAR.MODAL.SAVE')).toBeUndefined();
  });
});
