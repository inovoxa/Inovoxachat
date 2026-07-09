json.id calendar_event.id
json.title calendar_event.title
json.description calendar_event.description
json.location calendar_event.location
json.start_time calendar_event.start_time
json.end_time calendar_event.end_time
json.all_day calendar_event.all_day
json.timezone calendar_event.timezone
json.status calendar_event.status
json.source calendar_event.source
json.recurrence_rule calendar_event.recurrence_rule
json.external_event_id calendar_event.external_event_id
json.recurring calendar_event.recurring?
json.occurrence false
json.created_at calendar_event.created_at
json.updated_at calendar_event.updated_at

json.partial! 'api/v1/accounts/calendar_events/associations', event: calendar_event
