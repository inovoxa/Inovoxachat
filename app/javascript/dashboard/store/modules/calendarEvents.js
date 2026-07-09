import types from '../mutation-types';
import CalendarEventsAPI from '../../api/calendarEvents';

export const state = {
  // Ocorrências do intervalo atualmente carregado (eventos simples + recorrentes
  // expandidos pelo backend). A chave de identidade é `occurrence_id`.
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getCalendarEvents(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetch: async function fetchCalendarEvents({ commit }, filters = {}) {
    commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isFetching: true });
    try {
      const response = await CalendarEventsAPI.getInRange(filters);
      commit(types.SET_CALENDAR_EVENTS, response.data.payload);
      return response.data.payload;
    } catch (error) {
      return [];
    } finally {
      commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createCalendarEvent({ commit }, eventObj) {
    commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isCreating: true });
    try {
      const response = await CalendarEventsAPI.create({
        calendar_event: eventObj,
      });
      commit(types.ADD_CALENDAR_EVENT, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.error || error?.message);
    } finally {
      commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateCalendarEvent({ commit }, { id, ...eventObj }) {
    commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: true });
    try {
      const response = await CalendarEventsAPI.update(id, {
        calendar_event: eventObj,
      });
      commit(types.EDIT_CALENDAR_EVENT, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.error || error?.message);
    } finally {
      commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteCalendarEvent({ commit }, id) {
    commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: true });
    try {
      await CalendarEventsAPI.delete(id);
      commit(types.DELETE_CALENDAR_EVENT, id);
    } catch (error) {
      throw new Error(error?.response?.data?.error || error?.message);
    } finally {
      commit(types.SET_CALENDAR_EVENT_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_CALENDAR_EVENT_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },

  [types.SET_CALENDAR_EVENTS](_state, records) {
    _state.records = records;
  },

  // Após criar/editar, o board é recarregado via fetch; aqui só mantemos o
  // estado coerente sem duplicar a lógica de expansão de ocorrências.
  [types.ADD_CALENDAR_EVENT]() {},
  [types.EDIT_CALENDAR_EVENT]() {},

  [types.DELETE_CALENDAR_EVENT](_state, id) {
    _state.records = _state.records.filter(record => record.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
