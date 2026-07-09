<script setup>
import { computed, onMounted, ref } from 'vue';
import { fetchPage, fetchSlots, createBooking } from '../api/booking.js';

const slug = window.bookingConfig?.slug;
const visitorTz = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

const page = ref(null);
const loading = ref(true);
const loadError = ref(false);

const selectedDate = ref(null);
const slots = ref([]);
const slotsLoading = ref(false);
const selectedSlot = ref(null);

const form = ref({ guest_name: '', guest_email: '', guest_phone: '', notes: '' });
const submitting = ref(false);
const formError = ref('');
const confirmation = ref(null);

onMounted(async () => {
  try {
    page.value = await fetchPage(slug);
  } catch (e) {
    loadError.value = true;
  } finally {
    loading.value = false;
  }
});

// Próximos dias (até max_advance_days) cujo dia da semana tem disponibilidade.
const availableDays = computed(() => {
  if (!page.value) return [];
  const days = [];
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let i = 0; i <= page.value.max_advance_days; i += 1) {
    const date = new Date(today);
    date.setDate(today.getDate() + i);
    if (page.value.available_weekdays.includes(date.getDay())) {
      days.push(date);
    }
  }
  return days;
});

const toIsoDate = date => {
  const pad = n => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

const dayLabel = date =>
  date.toLocaleDateString(undefined, {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
  });

const slotLabel = slot =>
  new Date(slot.start_time).toLocaleTimeString(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  });

const selectDay = async date => {
  selectedDate.value = date;
  selectedSlot.value = null;
  slots.value = [];
  slotsLoading.value = true;
  try {
    const data = await fetchSlots(slug, toIsoDate(date));
    slots.value = data.payload || [];
  } catch (e) {
    slots.value = [];
  } finally {
    slotsLoading.value = false;
  }
};

const selectSlot = slot => {
  selectedSlot.value = slot;
  formError.value = '';
};

const canSubmit = computed(
  () =>
    selectedSlot.value &&
    form.value.guest_name.trim() &&
    /.+@.+\..+/.test(form.value.guest_email)
);

const submit = async () => {
  if (!canSubmit.value) {
    formError.value = 'Preencha nome e um e-mail válido.';
    return;
  }
  submitting.value = true;
  formError.value = '';
  try {
    confirmation.value = await createBooking(slug, {
      ...form.value,
      start_time: selectedSlot.value.start_time,
    });
  } catch (e) {
    formError.value =
      e.message === 'request_failed'
        ? 'Não foi possível concluir o agendamento. Tente novamente.'
        : e.message;
    // O horário pode ter sido tomado; recarrega os slots do dia.
    if (selectedDate.value) selectDay(selectedDate.value);
  } finally {
    submitting.value = false;
  }
};
</script>

<template>
  <div class="booking">
    <div v-if="loading" class="card">Carregando…</div>
    <div v-else-if="loadError" class="card">Página de agendamento não encontrada.</div>

    <div v-else-if="confirmation" class="card">
      <h1>Agendamento confirmado ✅</h1>
      <p>Enviamos os detalhes para o seu e-mail.</p>
      <a class="btn" :href="confirmation.ics_url">Adicionar à minha agenda (.ics)</a>
    </div>

    <div v-else class="card">
      <h1>{{ page.name }}</h1>
      <p v-if="page.description" class="muted">{{ page.description }}</p>
      <p class="muted small">Duração: {{ page.duration_minutes }} min · Fuso: {{ visitorTz }}</p>

      <section>
        <h2>1. Escolha o dia</h2>
        <div class="days">
          <button
            v-for="day in availableDays"
            :key="day.toISOString()"
            class="chip"
            :class="{ active: selectedDate && day.toDateString() === selectedDate.toDateString() }"
            @click="selectDay(day)"
          >
            {{ dayLabel(day) }}
          </button>
          <p v-if="!availableDays.length" class="muted">Sem dias disponíveis.</p>
        </div>
      </section>

      <section v-if="selectedDate">
        <h2>2. Escolha o horário</h2>
        <p v-if="slotsLoading" class="muted">Carregando horários…</p>
        <p v-else-if="!slots.length" class="muted">Nenhum horário livre neste dia.</p>
        <div v-else class="slots">
          <button
            v-for="slot in slots"
            :key="slot.start_time"
            class="chip"
            :class="{ active: selectedSlot && selectedSlot.start_time === slot.start_time }"
            @click="selectSlot(slot)"
          >
            {{ slotLabel(slot) }}
          </button>
        </div>
      </section>

      <section v-if="selectedSlot">
        <h2>3. Seus dados</h2>
        <input v-model="form.guest_name" placeholder="Nome completo" />
        <input v-model="form.guest_email" type="email" placeholder="E-mail" />
        <input v-model="form.guest_phone" placeholder="Telefone (opcional)" />
        <textarea v-model="form.notes" rows="3" placeholder="Observações (opcional)" />
        <p v-if="formError" class="error">{{ formError }}</p>
        <button class="btn" :disabled="submitting || !canSubmit" @click="submit">
          {{ submitting ? 'Agendando…' : 'Confirmar agendamento' }}
        </button>
      </section>
    </div>
  </div>
</template>

<style scoped>
.booking {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 24px 16px;
  background: #f4f7fb;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  color: #1f2d3d;
}
.card {
  width: 100%;
  max-width: 520px;
  background: #fff;
  border-radius: 14px;
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
  padding: 28px;
}
h1 {
  font-size: 22px;
  margin: 0 0 8px;
}
h2 {
  font-size: 15px;
  margin: 22px 0 10px;
}
.muted {
  color: #64748b;
}
.small {
  font-size: 13px;
}
.days,
.slots {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.chip {
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 999px;
  padding: 8px 14px;
  font-size: 14px;
  cursor: pointer;
}
.chip.active {
  background: #1f93ff;
  border-color: #1f93ff;
  color: #fff;
}
input,
textarea {
  width: 100%;
  box-sizing: border-box;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 10px 12px;
  font-size: 14px;
  margin-bottom: 10px;
}
.btn {
  display: inline-block;
  margin-top: 8px;
  background: #1f93ff;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 11px 18px;
  font-size: 15px;
  cursor: pointer;
  text-decoration: none;
}
.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.error {
  color: #e11d48;
  font-size: 14px;
}
</style>
