json.user_id event.user_id

json.attendees event.attendees do |attendee|
  json.id attendee.id
  json.user_id attendee.user_id
  json.email attendee.email
  json.name attendee.name
  json.response_status attendee.response_status
end

if event.conversation.present?
  json.conversation do
    json.id event.conversation.id
    json.display_id event.conversation.display_id
  end
end

if event.contact.present?
  json.contact do
    json.id event.contact.id
    json.name event.contact.name
    json.email event.contact.email
  end
end

if event.pipeline_stage.present?
  json.pipeline_stage do
    json.id event.pipeline_stage.id
    json.name event.pipeline_stage.name
    json.color event.pipeline_stage.color
    json.pipeline do
      json.id event.pipeline_stage.pipeline.id
      json.name event.pipeline_stage.pipeline.name
    end
  end
end
