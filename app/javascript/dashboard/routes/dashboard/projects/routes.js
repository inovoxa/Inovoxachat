import { frontendURL } from '../../../helper/URLHelper';
import ProjectBoard from './pages/ProjectBoard.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/projects/board'),
    name: 'projects_board',
    component: ProjectBoard,
    meta,
  },
];
