import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import BookingPagesAPI from '../../api/bookingPages';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getBookingPages(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function fetchBookingPages({ commit }) {
    commit(types.SET_BOOKING_PAGE_UI_FLAG, { isFetching: true });
    try {
      const response = await BookingPagesAPI.get();
      commit(types.SET_BOOKING_PAGES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_BOOKING_PAGE_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createBookingPage({ commit }, pageObj) {
    commit(types.SET_BOOKING_PAGE_UI_FLAG, { isCreating: true });
    try {
      const response = await BookingPagesAPI.create({ booking_page: pageObj });
      commit(types.ADD_BOOKING_PAGE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_BOOKING_PAGE_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateBookingPage({ commit }, { id, ...pageObj }) {
    commit(types.SET_BOOKING_PAGE_UI_FLAG, { isUpdating: true });
    try {
      const response = await BookingPagesAPI.update(id, {
        booking_page: pageObj,
      });
      commit(types.EDIT_BOOKING_PAGE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_BOOKING_PAGE_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteBookingPage({ commit }, id) {
    commit(types.SET_BOOKING_PAGE_UI_FLAG, { isDeleting: true });
    try {
      await BookingPagesAPI.delete(id);
      commit(types.DELETE_BOOKING_PAGE, id);
    } catch (error) {
      throw new Error(error?.response?.data?.message || error?.message);
    } finally {
      commit(types.SET_BOOKING_PAGE_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_BOOKING_PAGE_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_BOOKING_PAGES]: MutationHelpers.set,
  [types.ADD_BOOKING_PAGE]: MutationHelpers.create,
  [types.EDIT_BOOKING_PAGE]: MutationHelpers.update,
  [types.DELETE_BOOKING_PAGE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
