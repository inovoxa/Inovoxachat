/* global axios */
import ApiClient from './ApiClient';

// Endpoints do namespace calendar/ (conexões, autorização OAuth e credenciais).
class CalendarConnectionsAPI extends ApiClient {
  constructor() {
    super('calendar/connections', { accountScoped: true });
  }

  authorize(provider) {
    return axios.post(`${this.baseUrl()}/calendar/authorizations`, {
      provider,
    });
  }

  getOauthConfig() {
    return axios.get(`${this.baseUrl()}/calendar/oauth_config`);
  }

  updateOauthConfig(payload) {
    return axios.patch(`${this.baseUrl()}/calendar/oauth_config`, payload);
  }

  toggleSync(id, syncEnabled) {
    return axios.patch(`${this.url}/${id}`, {
      connection: { sync_enabled: syncEnabled },
    });
  }
}

export default new CalendarConnectionsAPI();
