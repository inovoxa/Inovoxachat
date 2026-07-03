import { frontendURL } from '../../../helper/URLHelper';
import CalendarView from './pages/CalendarView.vue';

const meta = { permissions: ['administrator', 'agent'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/calendar/meetings'),
    name: 'calendar_meetings',
    component: CalendarView,
    meta,
  },
];
