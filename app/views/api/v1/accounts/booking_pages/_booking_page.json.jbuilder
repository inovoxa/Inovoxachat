json.id booking_page.id
json.name booking_page.name
json.description booking_page.description
json.slug booking_page.slug
json.duration_minutes booking_page.duration_minutes
json.buffer_before_minutes booking_page.buffer_before_minutes
json.buffer_after_minutes booking_page.buffer_after_minutes
json.min_notice_hours booking_page.min_notice_hours
json.max_advance_days booking_page.max_advance_days
json.timezone booking_page.timezone
json.active booking_page.active
json.inbox_id booking_page.inbox_id
json.user_id booking_page.user_id
json.default_pipeline_stage_id booking_page.default_pipeline_stage_id
json.public_url "#{ENV.fetch('FRONTEND_URL', '')}/booking/#{booking_page.slug}"

json.availabilities booking_page.availabilities do |availability|
  json.id availability.id
  json.day_of_week availability.day_of_week
  json.start_time availability.start_time.strftime('%H:%M')
  json.end_time availability.end_time.strftime('%H:%M')
end
