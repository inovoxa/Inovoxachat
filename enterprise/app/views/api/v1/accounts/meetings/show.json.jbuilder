json.payload do
  json.partial! 'api/v1/models/meeting', formats: [:json], resource: @meeting
end
