json.id resource.id
json.codigo resource.codigo
json.stage resource.stage
json.company_id resource.company_id
json.company_name resource.company&.name
json.equipment_id resource.equipment_id
json.equipment_name resource.equipment&.name
json.product_name resource.product_name
json.in_warranty resource.in_warranty
json.scheduled_at resource.scheduled_at
json.notes resource.notes
json.position resource.position
json.assignee_id resource.assignee_id
if resource.assignee.present?
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
  end
end
