/* global axios */
import ApiClient from './ApiClient';

// Equipamentos para locação (módulo Empresas). Endpoint /api/v1/accounts/:id/equipments.
class EquipmentsAPI extends ApiClient {
  constructor() {
    super('equipments', { accountScoped: true });
  }

  // filtros: status (disponivel|alugado|manutencao)
  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new EquipmentsAPI();
