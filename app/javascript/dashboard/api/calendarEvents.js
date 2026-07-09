/* global axios */
import ApiClient from './ApiClient';

class CalendarEventsAPI extends ApiClient {
  constructor() {
    super('calendar_events', { accountScoped: true });
  }

  // Busca as ocorrências (eventos simples + recorrentes expandidos) num intervalo.
  // filters: { startDate, endDate, userId, pipelineId, conversationId, contactId }
  getInRange({
    startDate,
    endDate,
    userId,
    pipelineId,
    conversationId,
    contactId,
  } = {}) {
    return axios.get(this.url, {
      params: {
        start_date: startDate,
        end_date: endDate,
        user_id: userId,
        pipeline_id: pipelineId,
        conversation_id: conversationId,
        contact_id: contactId,
      },
    });
  }
}

export default new CalendarEventsAPI();
