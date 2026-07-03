json.payload do
  json.array! @orders do |order|
    json.partial! 'api/v1/models/repair_order', formats: [:json], resource: order
  end
end
