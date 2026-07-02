json.id resource.id
json.name resource.name
json.contacts_count resource.contacts_count
json.domain resource.domain
json.description resource.description
json.cnpj resource.cnpj
json.status resource.status
json.phone resource.phone
json.address resource.address
json.account_owner_id resource.account_owner_id
if resource.account_owner_id.present? && resource.account_owner.present?
  json.account_owner do
    json.id resource.account_owner.id
    json.name resource.account_owner.available_name
  end
end
json.custom_attributes resource.custom_attributes
json.avatar_url resource.avatar_url
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
json.updated_at resource.updated_at.to_i if resource[:updated_at].present?
