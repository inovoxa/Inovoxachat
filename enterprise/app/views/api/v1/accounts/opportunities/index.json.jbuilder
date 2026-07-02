json.payload do
  json.array! @opportunities do |opportunity|
    json.partial! 'api/v1/models/opportunity', formats: [:json], resource: opportunity
  end
end
