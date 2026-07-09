import { frontendURL } from '../../../helper/URLHelper';

import CalendarView from './pages/CalendarView.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/calendar'),
    name: 'calendar_view',
    component: CalendarView,
    meta: { permissions: ['administrator', 'agent'] },
  },
];
