/* global axios */
import ApiClient from './ApiClient';

// Contratos de locação (módulo Empresas). Endpoint /api/v1/accounts/:id/contracts.
class ContractsAPI extends ApiClient {
  constructor() {
    super('contracts', { accountScoped: true });
  }

  // filtros: filter (a_vencer|vencidos|ativos), days, status, company_id
  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new ContractsAPI();
