class Booking < ActiveRecord::Base
  has_many :booking_guests
  belongs_to :booking_request
end