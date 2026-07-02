import { frontendURL } from '../../../helper/URLHelper';
import SalesPipeline from './pages/SalesPipeline.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm/pipeline'),
    name: 'crm_pipeline',
    component: SalesPipeline,
    meta,
  },
];
