// Cliente da API pública de agendamento (sem sessão). Usa fetch para não
// depender do axios global do dashboard.
const base = slug => `/public/api/v1/booking_pages/${slug}`;

const parseJson = async response => {
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || 'request_failed');
  }
  return data;
};

export const fetchPage = slug => fetch(base(slug)).then(parseJson);

export const fetchSlots = (slug, date) =>
  fetch(`${base(slug)}/available_slots?date=${encodeURIComponent(date)}`).then(
    parseJson
  );

export const createBooking = (slug, payload) =>
  fetch(`${base(slug)}/bookings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).then(parseJson);
