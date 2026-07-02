json.id resource.id
json.name resource.name
json.stage resource.stage
json.expected_value resource.expected_value
json.probability resource.probability
json.rating resource.rating
json.position resource.position
json.notes resource.notes
json.expected_closing resource.expected_closing
json.company_id resource.company_id
json.company_name resource.company&.name
json.contact_id resource.contact_id
if resource.contact.present?
  json.contact do
    json.id resource.contact.id
    json.name resource.contact.name
    json.email resource.contact.email
    json.phone_number resource.contact.phone_number
  end
end
json.agent_id resource.agent_id
if resource.agent.present?
  json.agent do
    json.id resource.agent.id
    json.name resource.agent.available_name
  end
end
json.won_at resource.won_at
json.lost_at resource.lost_at
json.created_at resource.created_at.to_i if resource[:created_at].present?
