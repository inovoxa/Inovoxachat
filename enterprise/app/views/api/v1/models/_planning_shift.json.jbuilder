json.id resource.id
json.status resource.status
json.start_at resource.start_at
json.end_at resource.end_at
json.role resource.role
json.notes resource.notes
json.company_id resource.company_id
json.company_name resource.company&.name
json.resource_id resource.resource_id
if resource.resource.present?
  json.resource do
    json.id resource.resource.id
    json.name resource.resource.available_name
  end
end
