json.payload do
  json.array! @tasks do |item|
    json.partial! 'api/v1/models/project_task', formats: [:json], resource: item
  end
end
