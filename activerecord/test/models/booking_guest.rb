class BookingGuest < ActiveRecord::Base
  belongs_to :booking
  belongs_to :bookable, polymorphic: true
end