json.id resource.id
json.name resource.name
json.serial resource.serial
json.status resource.status
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
