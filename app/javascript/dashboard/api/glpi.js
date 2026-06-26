/* global axios */
import ApiClient from './ApiClient';

// Integração GLPI (multi-empresa): bate nos endpoints de proxy do Rails
// em /api/v1/accounts/:accountId/glpi/* (que repassam para a Central da conta).
class GlpiAPI extends ApiClient {
  constructor() {
    super('glpi', { accountScoped: true });
  }

  getConfig() {
    return axios.get(`${this.url}/config`);
  }

  updateConfig(config) {
    return axios.patch(`${this.url}/config`, { config });
  }

  getStatus() {
    return axios.get(`${this.url}/config/status`);
  }

  getTickets(params = {}) {
    return axios.get(`${this.url}/tickets`, { params });
  }

  updateTicketStatus(id, status) {
    return axios.patch(`${this.url}/tickets/${id}/status`, { status });
  }

  getAgente(params = {}) {
    return axios.get(`${this.url}/agente`, { params });
  }
}

export default new GlpiAPI();
