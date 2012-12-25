require 'active_support/core_ext/time/zones'

class DateTime
  # Returns the simultaneous time in <tt>Time.zone</tt>.
  #
  #   Time.zone = 'Hawaii'             # => 'Hawaii'
  #   DateTime.new(2000).in_time_zone  # => Fri, 31 Dec 1999 14:00:00 HST -10:00
  #
  # This method is similar to Time#localtime, except that it uses <tt>Time.zone</tt>
  # as the local zone instead of the operating system's time zone.
  #
  # You can also pass in a TimeZone instance or string that identifies a TimeZone
  # as an argument, and the conversion will be based on that zone instead of
  # <tt>Time.zone</tt>.
  #
  #   DateTime.new(2000).in_time_zone('Alaska') # => Fri, 31 Dec 1999 15:00:00 AKST -09:00
  def in_time_zone(zone = ::Time.zone)
    if zone
      ActiveSupport::TimeWithZone.new(utc? ? self : getutc, ::Time.find_zone!(zone))
    else
      self
    end
  end
end
