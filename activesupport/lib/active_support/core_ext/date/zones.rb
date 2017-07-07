require "date"
require_relative "../date_and_time/zones"

class Date
  include DateAndTime::Zones
end
