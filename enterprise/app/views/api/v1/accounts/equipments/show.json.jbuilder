json.payload do
  json.partial! 'api/v1/models/equipment', formats: [:json], resource: @equipment
end
