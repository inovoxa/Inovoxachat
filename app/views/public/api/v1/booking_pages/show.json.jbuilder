json.name @booking_page.name
json.description @booking_page.description
json.duration_minutes @booking_page.duration_minutes
json.timezone @booking_page.timezone
json.min_notice_hours @booking_page.min_notice_hours
json.max_advance_days @booking_page.max_advance_days
# Dias da semana (0-6) que possuem ao menos uma faixa de disponibilidade.
json.available_weekdays @booking_page.availabilities.distinct.pluck(:day_of_week).sort
