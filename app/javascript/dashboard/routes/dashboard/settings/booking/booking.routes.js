import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

const meta = {
  permissions: ['administrator'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/booking'),
      component: SettingsWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'booking_wrapper',
          meta,
          redirect: to => {
            return { name: 'booking_pages_index', params: to.params };
          },
        },
        {
          path: 'pages',
          name: 'booking_pages_index',
          meta,
          component: Index,
        },
      ],
    },
  ],
};
