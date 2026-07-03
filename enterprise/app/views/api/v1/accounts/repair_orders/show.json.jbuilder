json.payload do
  json.partial! 'api/v1/models/repair_order', formats: [:json], resource: @order
end
