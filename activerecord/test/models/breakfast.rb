class Breakfast < ActiveRecord::Base
  has_many :booking_guests, as: :bookable
end