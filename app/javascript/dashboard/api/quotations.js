/* global axios */
import ApiClient from './ApiClient';

// Cotações de venda/locação (módulo Vendas). Endpoint /api/v1/accounts/:id/quotations.
class QuotationsAPI extends ApiClient {
  constructor() {
    super('quotations', { accountScoped: true });
  }

  // filtros: status (cotacao|enviada|pedido|cancelada), company_id
  get(params = {}) {
    return axios.get(this.url, { params });
  }

  confirm(id) {
    return axios.post(`${this.url}/${id}/confirm`);
  }

  sendQuote(id) {
    return axios.post(`${this.url}/${id}/send_quote`);
  }

  cancel(id) {
    return axios.post(`${this.url}/${id}/cancel`);
  }
}

export default new QuotationsAPI();
