class BookingRequest < ActiveRecord::Base
  has_many    :bookings
  has_many    :booking_guests, through: :bookings
  has_many    :guests, through: :booking_guests, source: :bookable, source_type: "Guest"
  has_many    :breakfasts, through: :booking_guests, source: :bookable, source_type: "Breakfast"
end