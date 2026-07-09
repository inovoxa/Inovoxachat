import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

// Conectar/desconectar é por usuário, então agentes também acessam a tela;
// o bloco de credenciais OAuth dentro dela é restrito a administradores.
const meta = {
  permissions: ['administrator', 'agent'],
};

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/calendar'),
      component: SettingsWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'calendar_settings_wrapper',
          meta,
          redirect: to => {
            return { name: 'calendar_integrations_index', params: to.params };
          },
        },
        {
          path: 'integrations',
          name: 'calendar_integrations_index',
          meta,
          component: Index,
        },
      ],
    },
  ],
};
