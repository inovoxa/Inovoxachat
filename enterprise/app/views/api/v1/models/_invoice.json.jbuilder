json.id resource.id
json.company_id resource.company_id
json.company_name resource.company&.name
json.contract_id resource.contract_id
json.due_date resource.due_date
json.amount resource.amount
json.paid_at resource.paid_at
json.status resource.status
json.situacao resource.situacao
json.created_at resource.created_at.to_i if resource[:created_at].present?
