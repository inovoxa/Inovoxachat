json.payload do
  json.array! @projects do |item|
    json.partial! 'api/v1/models/project', formats: [:json], resource: item
  end
end
