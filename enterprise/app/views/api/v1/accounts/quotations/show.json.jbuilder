json.payload do
  json.partial! 'api/v1/models/quotation', formats: [:json], resource: @quotation
end
