json.payload do
  json.array! @equipments do |equipment|
    json.partial! 'api/v1/models/equipment', formats: [:json], resource: equipment
  end
end
