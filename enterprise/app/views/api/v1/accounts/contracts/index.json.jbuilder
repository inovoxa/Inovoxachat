json.payload do
  json.array! @contracts do |contract|
    json.partial! 'api/v1/models/contract', formats: [:json], resource: contract
  end
end
