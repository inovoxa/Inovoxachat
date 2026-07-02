json.id resource.id
json.company_id resource.company_id
json.company_name resource.company&.name
json.start_date resource.start_date
json.end_date resource.end_date
json.value resource.value
json.status resource.status
json.notes resource.notes
json.overdue resource.vencido_por_data?
json.items resource.contract_items do |item|
  json.id item.id
  json.equipment_id item.equipment_id
  json.equipment_name item.equipment&.name
  json.qty item.qty
  json.return_date item.return_date
end
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
