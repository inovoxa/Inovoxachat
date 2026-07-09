<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import CalendarConnectionsAPI from 'dashboard/api/calendarConnections';

const { t } = useI18n();

const currentRole = useMapGetter('getCurrentRole');
const isAdmin = computed(() => currentRole.value === 'administrator');

const PROVIDERS = ['google', 'outlook'];

const connections = ref([]);
const loading = ref(true);
const connecting = ref('');

// Credenciais OAuth (bloco admin). O secret é write-only: o GET só informa
// se há um salvo (secret_present); digitar um novo valor substitui.
const oauthConfig = reactive({
  google: { client_id: '', client_secret: '', secret_present: false },
  outlook: { client_id: '', client_secret: '', secret_present: false },
});
const savingConfig = ref(false);

const connectionByProvider = provider =>
  connections.value.find(connection => connection.provider === provider);

const loadConnections = async () => {
  loading.value = true;
  try {
    const { data } = await CalendarConnectionsAPI.get();
    connections.value = data.payload || [];
  } catch (e) {
    connections.value = [];
  } finally {
    loading.value = false;
  }
};

const loadOauthConfig = async () => {
  if (!isAdmin.value) return;
  try {
    const { data } = await CalendarConnectionsAPI.getOauthConfig();
    PROVIDERS.forEach(provider => {
      oauthConfig[provider].client_id = data[provider]?.client_id || '';
      oauthConfig[provider].secret_present = !!data[provider]?.secret_present;
      oauthConfig[provider].client_secret = '';
    });
  } catch (e) {
    // silencioso: bloco só aparece para admin
  }
};

onMounted(() => {
  loadConnections();
  loadOauthConfig();
});

const saveOauthConfig = async () => {
  savingConfig.value = true;
  try {
    const payload = {};
    PROVIDERS.forEach(provider => {
      payload[provider] = {
        client_id: oauthConfig[provider].client_id,
        client_secret: oauthConfig[provider].client_secret,
      };
    });
    const { data } = await CalendarConnectionsAPI.updateOauthConfig(payload);
    PROVIDERS.forEach(provider => {
      oauthConfig[provider].secret_present = !!data[provider]?.secret_present;
      oauthConfig[provider].client_secret = '';
    });
    useAlert(t('CALENDAR.INTEGRATIONS.CONFIG.SAVED'));
  } catch (e) {
    useAlert(t('CALENDAR.INTEGRATIONS.ERROR'));
  } finally {
    savingConfig.value = false;
  }
};

const connect = async provider => {
  connecting.value = provider;
  try {
    const { data } = await CalendarConnectionsAPI.authorize(provider);
    if (data.url) window.location.href = data.url;
  } catch (e) {
    useAlert(t('CALENDAR.INTEGRATIONS.AUTH_ERROR'));
  } finally {
    connecting.value = '';
  }
};

const toggleSync = async connection => {
  try {
    await CalendarConnectionsAPI.toggleSync(
      connection.id,
      !connection.sync_enabled
    );
    await loadConnections();
  } catch (e) {
    useAlert(t('CALENDAR.INTEGRATIONS.ERROR'));
  }
};

const disconnect = async connection => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CALENDAR.INTEGRATIONS.DISCONNECT_CONFIRM'))) return;
  try {
    await CalendarConnectionsAPI.delete(connection.id);
    useAlert(t('CALENDAR.INTEGRATIONS.DISCONNECTED'));
    await loadConnections();
  } catch (e) {
    useAlert(t('CALENDAR.INTEGRATIONS.ERROR'));
  }
};

const lastSyncLabel = connection => {
  if (!connection.last_synced_at) return t('CALENDAR.INTEGRATIONS.NEVER_SYNCED');
  return new Date(connection.last_synced_at).toLocaleString();
};
</script>

<template>
  <div class="flex flex-col w-full gap-6 py-2">
    <div>
      <h1 class="text-xl font-medium text-n-slate-12">
        {{ t('CALENDAR.INTEGRATIONS.HEADER') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ t('CALENDAR.INTEGRATIONS.DESCRIPTION') }}
      </p>
    </div>

    <!-- Credenciais OAuth (somente admin) -->
    <section
      v-if="isAdmin"
      class="rounded-xl border border-n-weak bg-n-solid-1 p-4 flex flex-col gap-4"
    >
      <div>
        <h2 class="text-base font-medium text-n-slate-12">
          {{ t('CALENDAR.INTEGRATIONS.CONFIG.TITLE') }}
        </h2>
        <p class="text-xs text-n-slate-11">
          {{ t('CALENDAR.INTEGRATIONS.CONFIG.HINT') }}
        </p>
      </div>

      <div
        v-for="provider in PROVIDERS"
        :key="provider"
        class="grid grid-cols-2 gap-3"
      >
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          {{ t(`CALENDAR.INTEGRATIONS.PROVIDERS.${provider.toUpperCase()}`) }} —
          Client ID
          <input
            v-model="oauthConfig[provider].client_id"
            type="text"
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 font-mono"
          />
        </label>
        <label class="flex flex-col gap-1 text-sm text-n-slate-11">
          Client Secret
          <input
            v-model="oauthConfig[provider].client_secret"
            type="password"
            :placeholder="
              oauthConfig[provider].secret_present
                ? t('CALENDAR.INTEGRATIONS.CONFIG.SECRET_SAVED')
                : t('CALENDAR.INTEGRATIONS.CONFIG.SECRET_PLACEHOLDER')
            "
            class="text-sm rounded-lg border border-n-weak bg-n-alpha-black2 px-3 py-2 text-n-slate-12 font-mono"
          />
        </label>
      </div>

      <button
        class="self-start px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
        :disabled="savingConfig"
        @click="saveOauthConfig"
      >
        {{ t('CALENDAR.INTEGRATIONS.CONFIG.SAVE') }}
      </button>
    </section>

    <!-- Conexões do usuário atual -->
    <section class="flex flex-col gap-3">
      <h2 class="text-base font-medium text-n-slate-12">
        {{ t('CALENDAR.INTEGRATIONS.MY_CONNECTIONS') }}
      </h2>

      <p v-if="loading" class="text-sm text-n-slate-11">
        {{ t('CALENDAR.INTEGRATIONS.LOADING') }}
      </p>

      <div
        v-for="provider in PROVIDERS"
        v-else
        :key="provider"
        class="flex items-center justify-between gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <div class="flex items-center gap-3 min-w-0">
          <span
            class="w-9 h-9 rounded-lg flex items-center justify-center text-white text-sm font-semibold"
            :class="provider === 'google' ? 'bg-[#10B981]' : 'bg-[#8B5CF6]'"
          >
            {{ provider === 'google' ? 'G' : 'O' }}
          </span>
          <div class="min-w-0">
            <p class="text-sm font-medium text-n-slate-12">
              {{ t(`CALENDAR.INTEGRATIONS.PROVIDERS.${provider.toUpperCase()}`) }}
            </p>
            <p
              v-if="connectionByProvider(provider)"
              class="text-xs text-n-slate-11 truncate"
            >
              {{ t('CALENDAR.INTEGRATIONS.LAST_SYNC') }}:
              {{ lastSyncLabel(connectionByProvider(provider)) }}
            </p>
            <p v-else class="text-xs text-n-slate-10">
              {{ t('CALENDAR.INTEGRATIONS.NOT_CONNECTED') }}
            </p>
          </div>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <template v-if="connectionByProvider(provider)">
            <label class="flex items-center gap-1.5 text-xs text-n-slate-11">
              <input
                type="checkbox"
                :checked="connectionByProvider(provider).sync_enabled"
                @change="toggleSync(connectionByProvider(provider))"
              />
              {{ t('CALENDAR.INTEGRATIONS.SYNC_ENABLED') }}
            </label>
            <button
              class="text-xs text-red-500 hover:underline"
              @click="disconnect(connectionByProvider(provider))"
            >
              {{ t('CALENDAR.INTEGRATIONS.DISCONNECT') }}
            </button>
          </template>
          <button
            v-else
            class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600 disabled:opacity-50"
            :disabled="connecting === provider"
            @click="connect(provider)"
          >
            {{ t('CALENDAR.INTEGRATIONS.CONNECT') }}
          </button>
        </div>
      </div>
    </section>
  </div>
</template>
