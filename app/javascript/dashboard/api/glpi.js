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

  getInventario(params = {}) {
    return axios.get(`${this.url}/inventario`, { params });
  }

  getInventarioItem(id) {
    return axios.get(`${this.url}/inventario/${id}`);
  }

  getUsuarioAd(login) {
    return axios.get(`${this.url}/usuario_ad`, { params: { login } });
  }

  getAprovadores() {
    return axios.get(`${this.url}/aprovadores`);
  }

  addAprovador(login, nome) {
    return axios.post(`${this.url}/aprovadores`, { login, nome });
  }

  removeAprovador(login) {
    return axios.delete(`${this.url}/aprovadores/${encodeURIComponent(login)}`);
  }

  syncAprovadores() {
    return axios.post(`${this.url}/aprovadores/sync`);
  }

  importAprovadores() {
    return axios.get(`${this.url}/aprovadores/import`);
  }
}

export default new GlpiAPI();
