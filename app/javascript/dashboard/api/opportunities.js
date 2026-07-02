/* global axios */
import ApiClient from './ApiClient';

// CRM — funil de vendas. Endpoint /api/v1/accounts/:id/opportunities.
class OpportunitiesAPI extends ApiClient {
  constructor() {
    super('opportunities', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  move(id, stage, position = 0) {
    return axios.patch(`${this.url}/${id}/move`, { stage, position });
  }

  ganhar(id, gerarContrato = true) {
    return axios.post(`${this.url}/${id}/ganhar`, { gerar_contrato: gerarContrato });
  }

  perder(id) {
    return axios.post(`${this.url}/${id}/perder`);
  }
}

export default new OpportunitiesAPI();
