import { createApp } from 'vue';
import App from '../booking/App.vue';

const app = createApp(App);

window.onload = () => {
  window.WOOT_BOOKING = app.mount('#app');
};
