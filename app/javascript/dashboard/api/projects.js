/* global axios */
import ApiClient from './ApiClient';

class ProjectsAPI extends ApiClient {
  constructor() {
    super('projects', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new ProjectsAPI();
