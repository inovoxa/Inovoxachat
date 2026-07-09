<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import BookingPageForm from './components/BookingPageForm.vue';

const store = useStore();
const { t } = useI18n();

const pages = useMapGetter('bookingPages/getBookingPages');
const uiFlags = useMapGetter('bookingPages/getUIFlags');

const showForm = ref(false);
const editingPage = ref(null);

onMounted(() => {
  store.dispatch('bookingPages/get');
});

const openNew = () => {
  editingPage.value = null;
  showForm.value = true;
};

const openEdit = page => {
  editingPage.value = page;
  showForm.value = true;
};

const onSaved = () => {
  showForm.value = false;
  store.dispatch('bookingPages/get');
};

const copyLink = async page => {
  await copyTextToClipboard(page.public_url);
  useAlert(t('BOOKING.LINK_COPIED'));
};

const remove = async page => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('BOOKING.DELETE_CONFIRM', { name: page.name }))) return;
  try {
    await store.dispatch('bookingPages/delete', page.id);
    useAlert(t('BOOKING.DELETED'));
  } catch (e) {
    useAlert(e?.message || t('BOOKING.ERROR'));
  }
};
</script>

<template>
  <div class="flex flex-col w-full gap-4 py-2">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-medium text-n-slate-12">
          {{ t('BOOKING.HEADER') }}
        </h1>
        <p class="text-sm text-n-slate-11">{{ t('BOOKING.DESCRIPTION') }}</p>
      </div>
      <button
        class="px-3 py-1.5 text-sm rounded-lg bg-woot-500 text-white hover:bg-woot-600"
        @click="openNew"
      >
        {{ t('BOOKING.NEW') }}
      </button>
    </div>

    <p v-if="uiFlags.isFetching" class="text-sm text-n-slate-11">
      {{ t('BOOKING.LOADING') }}
    </p>

    <p
      v-else-if="!pages.length"
      class="text-sm text-n-slate-11 text-center py-8"
    >
      {{ t('BOOKING.EMPTY') }}
    </p>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="page in pages"
        :key="page.id"
        class="flex items-center justify-between gap-3 rounded-lg border border-n-weak bg-n-solid-1 p-3"
      >
        <div class="min-w-0">
          <p class="text-sm font-medium text-n-slate-12 truncate">
            {{ page.name }}
            <span
              v-if="!page.active"
              class="ml-2 text-[10px] uppercase text-n-slate-10"
            >
              {{ t('BOOKING.INACTIVE') }}
            </span>
          </p>
          <p class="text-xs text-n-slate-11 truncate">/{{ page.slug }}</p>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <button
            class="text-xs text-n-slate-11 hover:text-n-slate-12"
            @click="copyLink(page)"
          >
            {{ t('BOOKING.COPY_LINK') }}
          </button>
          <button
            class="text-xs text-woot-500 hover:underline"
            @click="openEdit(page)"
          >
            {{ t('BOOKING.EDIT') }}
          </button>
          <button
            class="text-xs text-red-500 hover:underline"
            @click="remove(page)"
          >
            {{ t('BOOKING.DELETE') }}
          </button>
        </div>
      </div>
    </div>

    <BookingPageForm
      v-if="showForm"
      :page="editingPage"
      @close="showForm = false"
      @saved="onSaved"
    />
  </div>
</template>
