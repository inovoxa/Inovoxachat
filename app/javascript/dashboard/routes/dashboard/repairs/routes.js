import { frontendURL } from '../../../helper/URLHelper';
import RepairBoard from './pages/RepairBoard.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/repairs/board'),
    name: 'repairs_board',
    component: RepairBoard,
    meta,
  },
];
