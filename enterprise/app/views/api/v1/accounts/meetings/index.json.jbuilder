json.payload do
  json.array! @meetings do |meeting|
    json.partial! 'api/v1/models/meeting', formats: [:json], resource: meeting
  end
end
