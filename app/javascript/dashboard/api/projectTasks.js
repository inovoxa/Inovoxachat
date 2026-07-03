/* global axios */
import ApiClient from './ApiClient';

class ProjectTasksAPI extends ApiClient {
  constructor() {
    super('project_tasks', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  move(id, stage, position = 0) {
    return axios.patch(`${this.url}/${id}/move`, { stage, position });
  }
}

export default new ProjectTasksAPI();
