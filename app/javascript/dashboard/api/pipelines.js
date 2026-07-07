/* global axios */
import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getTemplates() {
    return axios.get(`${this.url}/templates`);
  }

  getCards(pipelineId, { days = 30 } = {}) {
    return axios.get(`${this.url}/${pipelineId}/cards`, { params: { days } });
  }

  createStage(pipelineId, stageObj) {
    return axios.post(`${this.url}/${pipelineId}/stages`, stageObj);
  }

  updateStage(pipelineId, stageId, stageObj) {
    return axios.patch(`${this.url}/${pipelineId}/stages/${stageId}`, stageObj);
  }

  deleteStage(pipelineId, stageId) {
    return axios.delete(`${this.url}/${pipelineId}/stages/${stageId}`);
  }

  reorderStages(pipelineId, stageIds) {
    return axios.post(`${this.url}/${pipelineId}/stages/reorder`, {
      stage_ids: stageIds,
    });
  }

  moveConversation(conversationId, pipelineStageId) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/assign_pipeline_stage`,
      { pipeline_stage_id: pipelineStageId }
    );
  }

  moveContact(contactId, pipelineStageId) {
    return axios.post(
      `${this.baseUrl()}/contacts/${contactId}/assign_pipeline_stage`,
      { pipeline_stage_id: pipelineStageId }
    );
  }
}

export default new PipelinesAPI();
