json.id resource.id
json.number resource.number
json.status resource.status
json.company_id resource.company_id
json.company_name resource.company&.name
json.contact_id resource.contact_id
json.contact_name resource.contact&.name
json.agent_id resource.agent_id
json.agent_name resource.agent&.name
json.opportunity_id resource.opportunity_id
json.expiration_date resource.expiration_date
json.recurring_plan resource.recurring_plan
json.recurring_until resource.recurring_until
json.payment_terms resource.payment_terms
json.delivery_date resource.delivery_date
json.amount_total resource.amount_total
json.notes resource.notes
json.lines resource.quotation_lines do |line|
  json.id line.id
  json.equipment_id line.equipment_id
  json.equipment_name line.equipment&.name
  json.is_section line.is_section
  json.name line.name
  json.qty line.qty
  json.unit_price line.unit_price
  json.tax_percent line.tax_percent
  json.discount_percent line.discount_percent
  json.amount line.amount
  json.position line.position
end
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
