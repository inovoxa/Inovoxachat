json.id resource.id
json.project_id resource.project_id
json.title resource.title
json.stage resource.stage
json.position resource.position
json.assignee_id resource.assignee_id
if resource.assignee.present?
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
  end
end
