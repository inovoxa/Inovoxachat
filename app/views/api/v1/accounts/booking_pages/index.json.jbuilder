json.payload do
  json.array! @booking_pages, partial: 'api/v1/accounts/booking_pages/booking_page', as: :booking_page
end
