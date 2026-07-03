/* global axios */
import ApiClient from './ApiClient';

class PlanningShiftsAPI extends ApiClient {
  constructor() {
    super('planning_shifts', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new PlanningShiftsAPI();
