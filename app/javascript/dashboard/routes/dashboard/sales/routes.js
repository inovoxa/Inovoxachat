import { frontendURL } from '../../../helper/URLHelper';
import SalesView from './pages/SalesView.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/sales/quotations'),
    name: 'sales_quotations',
    component: SalesView,
    meta,
  },
];
