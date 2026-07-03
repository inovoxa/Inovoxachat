/* global axios */
import ApiClient from './ApiClient';

class MeetingsAPI extends ApiClient {
  constructor() {
    super('meetings', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new MeetingsAPI();
