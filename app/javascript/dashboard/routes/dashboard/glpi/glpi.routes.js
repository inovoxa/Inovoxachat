import { frontendURL } from '../../../helper/URLHelper';

import ChamadosIndex from './pages/ChamadosIndex.vue';
import KanbanBoard from './pages/KanbanBoard.vue';
import AgenteIA from './pages/AgenteIA.vue';
import GlpiConfig from './pages/GlpiConfig.vue';

const meta = { permissions: ['administrator', 'agent'] };
const adminMeta = { permissions: ['administrator'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/glpi/chamados'),
    name: 'glpi_chamados',
    component: ChamadosIndex,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/glpi/kanban'),
    name: 'glpi_kanban',
    component: KanbanBoard,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/glpi/agente'),
    name: 'glpi_agente',
    component: AgenteIA,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/glpi/config'),
    name: 'glpi_config',
    component: GlpiConfig,
    meta: adminMeta,
  },
];
