json.payload do
  json.array! @shifts do |shift|
    json.partial! 'api/v1/models/planning_shift', formats: [:json], resource: shift
  end
end
