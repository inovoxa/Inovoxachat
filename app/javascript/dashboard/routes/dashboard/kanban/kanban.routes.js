import { frontendURL } from '../../../helper/URLHelper';

import KanbanView from './pages/KanbanView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_view',
    component: KanbanView,
    meta: { permissions: ['administrator', 'agent'] },
  },
];
