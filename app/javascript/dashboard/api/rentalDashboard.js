/* global axios */
import ApiClient from './ApiClient';

// Painel de Controle do módulo Empresas. Endpoint /api/v1/accounts/:id/rental_dashboard.
class RentalDashboardAPI extends ApiClient {
  constructor() {
    super('rental_dashboard', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }
}

export default new RentalDashboardAPI();
