json.payload do
  json.partial! 'api/v1/models/invoice', formats: [:json], resource: @invoice
end
