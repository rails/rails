require 'active_support/core_ext/date_and_time/compatibility'

class DateTime
  prepend DateAndTime::Compatibility

  # Returns a <tt>Time.local()</tt> instance of the simultaneous time in your
  # system's <tt>ENV['TZ']</tt> zone.
  def getlocal(utc_offset = nil)
    utc = getutc

    Time.utc(
      utc.year, utc.month, utc.day,
      utc.hour, utc.min, utc.sec + utc.sec_fraction
    ).getlocal(utc_offset)
  end
end
