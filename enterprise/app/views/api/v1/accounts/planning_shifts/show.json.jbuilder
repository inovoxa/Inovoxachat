json.payload do
  json.partial! 'api/v1/models/planning_shift', formats: [:json], resource: @shift
end
