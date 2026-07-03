/* global axios */
import ApiClient from './ApiClient';

class RepairOrdersAPI extends ApiClient {
  constructor() {
    super('repair_orders', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  move(id, stage, position = 0) {
    return axios.patch(`${this.url}/${id}/move`, { stage, position });
  }
}

export default new RepairOrdersAPI();
