require 'date'
require 'active_support/core_ext/time/zones'

class Date
  # *DEPRECATED*: Use +Date#in_time_zone+ instead.
  #
  # Converts Date to a TimeWithZone in the current zone if <tt>Time.zone</tt> or
  # <tt>Time.zone_default</tt> is set, otherwise converts Date to a Time via
  # Date#to_time.
  def to_time_in_current_zone
    ActiveSupport::Deprecation.warn 'Date#to_time_in_current_zone is deprecated. Use Date#in_time_zone instead', caller

    if ::Time.zone
      ::Time.zone.local(year, month, day)
    else
      to_time
    end
  end

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
