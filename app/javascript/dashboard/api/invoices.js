/* global axios */
import ApiClient from './ApiClient';

// Faturas (módulo Empresas — financeiro). Endpoint /api/v1/accounts/:id/invoices.
class InvoicesAPI extends ApiClient {
  constructor() {
    super('invoices', { accountScoped: true });
  }

  // filtros: filter (pendentes|inadimplencia|pagas), company_id
  get(params = {}) {
    return axios.get(this.url, { params });
  }

  pagar(id) {
    return axios.post(`${this.url}/${id}/pagar`);
  }
}

export default new InvoicesAPI();
