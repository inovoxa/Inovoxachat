json.id resource.id
json.title resource.title
json.start_at resource.start_at
json.end_at resource.end_at
json.location resource.location
json.description resource.description
json.participant_ids resource.participant_ids
json.company_id resource.company_id
json.company_name resource.company&.name
json.organizer_id resource.organizer_id
if resource.organizer.present?
  json.organizer do
    json.id resource.organizer.id
    json.name resource.organizer.available_name
  end
end
