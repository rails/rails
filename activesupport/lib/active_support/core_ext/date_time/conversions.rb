require 'date'
require 'active_support/inflector/methods'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/calculations'
require 'active_support/core_ext/date_and_time/conversions'
require 'active_support/values/time_zone'

class DateTime
  include DateAndTime::Conversions
  DATE_FORMATS = ::Time::DATE_FORMATS

  #
  #   datetime = DateTime.civil(2000, 1, 1, 0, 0, 0, Rational(-6, 24))
  #   datetime.formatted_offset         # => "-06:00"
  #   datetime.formatted_offset(false)  # => "-0600"
  def formatted_offset(colon = true, alternate_utc_string = nil)
    utc? && alternate_utc_string || ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset, colon)
  end

  # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005 14:30:00 +0000".
  def readable_inspect
    to_s(:rfc822)
  end
  alias_method :default_inspect, :inspect
  alias_method :inspect, :readable_inspect

  # Returns DateTime with local offset for given year if format is local else
  # offset is zero.
  #
  #   DateTime.civil_from_format :local, 2012
  #   # => Sun, 01 Jan 2012 00:00:00 +0300
  #   DateTime.civil_from_format :local, 2012, 12, 17
  #   # => Mon, 17 Dec 2012 00:00:00 +0000
  def self.civil_from_format(utc_or_local, year, month=1, day=1, hour=0, min=0, sec=0)
    if utc_or_local.to_sym == :local
      offset = ::Time.local(year, month, day).utc_offset.to_r / 86400
    else
      offset = 0
    end
    civil(year, month, day, hour, min, sec, offset)
  end

  # Converts +self+ to a floating-point number of seconds, including fractional microseconds, since the Unix epoch.
  def to_f
    seconds_since_unix_epoch.to_f + sec_fraction
  end

  # Converts +self+ to an integer number of seconds since the Unix epoch.
  def to_i
    seconds_since_unix_epoch.to_i
  end

  # Returns the fraction of a second as microseconds
  def usec
    (sec_fraction * 1_000_000).to_i
  end

  # Returns the fraction of a second as nanoseconds
  def nsec
    (sec_fraction * 1_000_000_000).to_i
  end

  private

  def offset_in_seconds
    (offset * 86400).to_i
  end

  def seconds_since_unix_epoch
    (jd - 2440588) * 86400 - offset_in_seconds + seconds_since_midnight
  end
end
