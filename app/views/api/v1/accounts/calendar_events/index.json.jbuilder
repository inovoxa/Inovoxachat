json.payload do
  json.array! @occurrences do |occurrence|
    event = occurrence[:record]

    json.id occurrence[:id]
    json.occurrence occurrence[:occurrence]
    json.occurrence_id occurrence[:occurrence_id]
    json.title occurrence[:title]
    json.description occurrence[:description]
    json.location occurrence[:location]
    json.start_time occurrence[:start_time]
    json.end_time occurrence[:end_time]
    json.all_day occurrence[:all_day]
    json.timezone occurrence[:timezone]
    json.status occurrence[:status]
    json.source occurrence[:source]
    json.recurrence_rule occurrence[:recurrence_rule]
    json.external_event_id event.external_event_id

    json.partial! 'api/v1/accounts/calendar_events/associations', event: event
  end
end

json.meta do
  json.count @occurrences.length
end
