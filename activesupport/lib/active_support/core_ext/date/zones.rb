require 'date'
require 'active_support/core_ext/time/zones'

class Date
  # Converts Date to a TimeWithZone in the current zone if Time.zone or Time.zone_default
  # is set, otherwise converts Date to a Time via Date#to_time
  #
  #   Time.zone = 'Hawaii'         # => 'Hawaii'
  #   Date.new(2000).in_time_zone  # => Sat, 01 Jan 2000 00:00:00 HST -10:00
  #
  # You can also pass in a TimeZone instance or string that identifies a TimeZone as an argument,
  # and the conversion will be based on that zone instead of <tt>Time.zone</tt>.
  #
  #   Date.new(2000).in_time_zone('Alaska')  # => Sat, 01 Jan 2000 00:00:00 AKST -09:00
  def in_time_zone(zone = ::Time.zone)
    if zone
      ::Time.find_zone!(zone).local(year, month, day)
    else
      to_time
    end
  end
end
