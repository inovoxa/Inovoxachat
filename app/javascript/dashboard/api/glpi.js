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

  testConfig() {
    return axios.get(`${this.url}/config/test`);
  }

  getOverview(params = {}) {
    return axios.get(`${this.url}/overview`, { params });
  }

  getTickets(params = {}) {
    return axios.get(`${this.url}/tickets`, { params });
  }

  getTicket(id) {
    return axios.get(`${this.url}/tickets/${id}`);
  }

  updateTicketStatus(id, status) {
    return axios.patch(`${this.url}/tickets/${id}/status`, { status });
  }

  getAgente(params = {}) {
    return axios.get(`${this.url}/agente`, { params });
  }

  getAtividade(params = {}) {
    return axios.get(`${this.url}/atividade`, { params });
  }

  getAprovadores() {
    return axios.get(`${this.url}/aprovadores`);
  }

  addAprovador(login) {
    return axios.post(`${this.url}/aprovadores`, { login });
  }

  removeAprovador(login) {
    return axios.delete(`${this.url}/aprovadores/${encodeURIComponent(login)}`);
  }
}

export default new GlpiAPI();
