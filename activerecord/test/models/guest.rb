class Guest < ActiveRecord::Base
  has_many :booking_guests, as: :bookable
end