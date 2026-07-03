json.payload do
  json.partial! 'api/v1/models/project_task', formats: [:json], resource: @task
end
