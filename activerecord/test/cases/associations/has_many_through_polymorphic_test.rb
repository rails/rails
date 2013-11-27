require 'cases/helper'
require 'models/booking'
require 'models/guest'
require 'models/breakfast'
require 'models/booking_request'
require 'models/booking_guest'

class BelongsToAssociationsTest < ActiveRecord::TestCase
  fixtures :bookings, :guests, :breakfasts, :booking_requests, :booking_guests

  def test_calling_twice
    booking_request = BookingRequest.find(1)
    assert_not_nil booking_request
    assert_equal booking_request.breakfasts.count, 1
    assert_equal booking_request.guests.count, 1
  end
end