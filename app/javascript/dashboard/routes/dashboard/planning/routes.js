import { frontendURL } from '../../../helper/URLHelper';
import PlanningBoard from './pages/PlanningBoard.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/planning/board'),
    name: 'planning_board',
    component: PlanningBoard,
    meta,
  },
];
