import ApiClient from './ApiClient';

class BookingPagesAPI extends ApiClient {
  constructor() {
    super('booking_pages', { accountScoped: true });
  }
}

export default new BookingPagesAPI();
