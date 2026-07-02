json.payload do
  json.array! @invoices do |invoice|
    json.partial! 'api/v1/models/invoice', formats: [:json], resource: invoice
  end
end
