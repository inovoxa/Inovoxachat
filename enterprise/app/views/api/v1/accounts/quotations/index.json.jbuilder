json.payload do
  json.array! @quotations do |quotation|
    json.partial! 'api/v1/models/quotation', formats: [:json], resource: quotation
  end
end
