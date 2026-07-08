/* global axios */

// Endpoints de mensagens agendadas, aninhados na conversa (por display_id).
class ScheduledMessagesAPI {
  // eslint-disable-next-line class-methods-use-this
  baseUrl(conversationId) {
    const accountId = window.location.pathname.split('/')[3];
    return `/api/v1/accounts/${accountId}/conversations/${conversationId}/scheduled_messages`;
  }

  get(conversationId) {
    return axios.get(this.baseUrl(conversationId));
  }

  create(conversationId, payload) {
    return axios.post(this.baseUrl(conversationId), {
      scheduled_message: payload,
    });
  }

  delete(conversationId, id) {
    return axios.delete(`${this.baseUrl(conversationId)}/${id}`);
  }
}

export default new ScheduledMessagesAPI();
