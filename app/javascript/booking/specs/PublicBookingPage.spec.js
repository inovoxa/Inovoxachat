import { mount, flushPromises } from '@vue/test-utils';
import PublicBookingPage from '../views/PublicBookingPage.vue';

const mocks = vi.hoisted(() => ({
  fetchPage: vi.fn(),
  fetchSlots: vi.fn(),
  createBooking: vi.fn(),
}));

vi.mock('../api/booking.js', () => ({
  fetchPage: mocks.fetchPage,
  fetchSlots: mocks.fetchSlots,
  createBooking: mocks.createBooking,
}));

describe('PublicBookingPage', () => {
  beforeEach(() => {
    window.bookingConfig = { slug: 'comercial', name: 'Comercial' };
    // available_weekdays com todos os dias para tornar availableDays não vazio.
    mocks.fetchPage.mockResolvedValue({
      name: 'Comercial',
      description: 'Reunião comercial',
      duration_minutes: 30,
      timezone: 'UTC',
      min_notice_hours: 0,
      max_advance_days: 30,
      available_weekdays: [0, 1, 2, 3, 4, 5, 6],
    });
    mocks.fetchSlots.mockResolvedValue({
      payload: [{ start_time: '2026-01-01T13:00:00Z', end_time: '2026-01-01T13:30:00Z' }],
    });
  });

  it('renders the page name after loading', async () => {
    const wrapper = mount(PublicBookingPage);
    await flushPromises();
    expect(wrapper.text()).toContain('Comercial');
  });

  it('formats slot times in the visitor timezone (UTC in tests)', async () => {
    const wrapper = mount(PublicBookingPage);
    await flushPromises();

    // Clica no primeiro dia disponível para carregar os horários.
    await wrapper.find('.days .chip').trigger('click');
    await flushPromises();

    const slotButtons = wrapper.findAll('.slots .chip');
    expect(slotButtons.length).toBe(1);
    expect(slotButtons[0].text()).toBe('13:00');
  });
});
