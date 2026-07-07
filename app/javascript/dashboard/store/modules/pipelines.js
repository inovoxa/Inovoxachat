import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import PipelinesAPI from '../../api/pipelines';

export const state = {
  records: [],
  templates: [],
  currentPipelineId: null,
  board: {
    pipelineId: null,
    stages: [],
  },
  uiFlags: {
    isFetching: false,
    isFetchingBoard: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getPipelines(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getTemplates(_state) {
    return _state.templates;
  },
  getCurrentPipeline(_state) {
    return (
      _state.records.find(
        record => record.id === Number(_state.currentPipelineId)
      ) ||
      _state.records[0] ||
      {}
    );
  },
  getStagesByPipelineId: _state => pipelineId => {
    const pipeline = _state.records.find(
      record => record.id === Number(pipelineId)
    );
    return pipeline ? pipeline.stages : [];
  },
  getBoard(_state) {
    return _state.board;
  },
};

export const actions = {
  get: async function fetchPipelines({ commit }) {
    commit(types.SET_PIPELINE_UI_FLAG, { isFetching: true });
    try {
      const response = await PipelinesAPI.get();
      commit(types.SET_PIPELINES, response.data.payload);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_PIPELINE_UI_FLAG, { isFetching: false });
    }
  },

  fetchTemplates: async function fetchTemplates({ commit }) {
    try {
      const response = await PipelinesAPI.getTemplates();
      commit(types.SET_PIPELINE_TEMPLATES, response.data.payload);
    } catch (error) {
      // Ignore error
    }
  },

  create: async function createPipeline({ commit }, pipelineObj) {
    commit(types.SET_PIPELINE_UI_FLAG, { isCreating: true });
    try {
      const response = await PipelinesAPI.create(pipelineObj);
      commit(types.ADD_PIPELINE, response.data);
      commit(types.SET_CURRENT_PIPELINE, response.data.id);
      return response.data;
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINE_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updatePipeline({ commit }, { id, ...updateObj }) {
    commit(types.SET_PIPELINE_UI_FLAG, { isUpdating: true });
    try {
      const response = await PipelinesAPI.update(id, updateObj);
      commit(types.EDIT_PIPELINE, response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINE_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deletePipeline({ commit }, id) {
    commit(types.SET_PIPELINE_UI_FLAG, { isDeleting: true });
    try {
      await PipelinesAPI.delete(id);
      commit(types.DELETE_PIPELINE, id);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_PIPELINE_UI_FLAG, { isDeleting: false });
    }
  },

  setCurrentPipeline({ commit }, pipelineId) {
    commit(types.SET_CURRENT_PIPELINE, pipelineId);
  },

  fetchCards: async function fetchCards({ commit }, { pipelineId, days }) {
    commit(types.SET_PIPELINE_UI_FLAG, { isFetchingBoard: true });
    try {
      const response = await PipelinesAPI.getCards(pipelineId, { days });
      commit(types.SET_PIPELINE_BOARD, {
        pipelineId,
        stages: response.data.payload,
      });
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_PIPELINE_UI_FLAG, { isFetchingBoard: false });
    }
  },

  createStage: async function createStage(
    { dispatch },
    { pipelineId, ...stageObj }
  ) {
    await PipelinesAPI.createStage(pipelineId, stageObj);
    await dispatch('refreshPipeline', pipelineId);
  },

  updateStage: async function updateStage(
    { dispatch },
    { pipelineId, id, ...stageObj }
  ) {
    await PipelinesAPI.updateStage(pipelineId, id, stageObj);
    await dispatch('refreshPipeline', pipelineId);
  },

  deleteStage: async function deleteStage({ dispatch }, { pipelineId, id }) {
    await PipelinesAPI.deleteStage(pipelineId, id);
    await dispatch('refreshPipeline', pipelineId);
  },

  reorderStages: async function reorderStages(
    { dispatch },
    { pipelineId, stageIds }
  ) {
    await PipelinesAPI.reorderStages(pipelineId, stageIds);
    await dispatch('refreshPipeline', pipelineId);
  },

  refreshPipeline: async function refreshPipeline({ commit }, pipelineId) {
    const response = await PipelinesAPI.show(pipelineId);
    commit(types.EDIT_PIPELINE, response.data);
  },

  moveConversationToStage: async function moveConversationToStage(
    _,
    { conversationId, stageId }
  ) {
    await PipelinesAPI.moveConversation(conversationId, stageId);
  },

  moveContactToStage: async function moveContactToStage(
    _,
    { contactId, stageId }
  ) {
    await PipelinesAPI.moveContact(contactId, stageId);
  },
};

export const mutations = {
  [types.SET_PIPELINE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_PIPELINES]: MutationHelpers.set,
  [types.ADD_PIPELINE]: MutationHelpers.create,
  [types.EDIT_PIPELINE]: MutationHelpers.update,
  [types.DELETE_PIPELINE]: MutationHelpers.destroy,

  [types.SET_PIPELINE_TEMPLATES](_state, templates) {
    _state.templates = templates;
  },

  [types.SET_PIPELINE_BOARD](_state, board) {
    _state.board = board;
  },

  [types.SET_CURRENT_PIPELINE](_state, pipelineId) {
    _state.currentPipelineId = pipelineId;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
