require 'active_support/inflector/methods'
require 'active_support/core_ext/time/publicize_conversion_methods'
require 'active_support/values/time_zone'

class Time
  DATE_FORMATS = {
    :db           => "%Y-%m-%d %H:%M:%S",
    :number       => "%Y%m%d%H%M%S",
    :time         => "%H:%M",
    :short        => "%d %b %H:%M",
    :long         => "%B %d, %Y %H:%M",
    :long_ordinal => lambda { |time| time.strftime("%B #{ActiveSupport::Inflector.ordinalize(time.day)}, %Y %H:%M") },
    :rfc822       => lambda { |time| time.strftime("%a, %d %b %Y %H:%M:%S #{time.formatted_offset(false)}") }
  }

  # Converts to a formatted string. See DATE_FORMATS for builtin formats.
  #
  # This method is aliased to <tt>to_s</tt>.
  #
  #   time = Time.now                     # => Thu Jan 18 06:10:17 CST 2007
  #
  #   time.to_formatted_s(:time)          # => "06:10:17"
  #   time.to_s(:time)                    # => "06:10:17"
  #
  #   time.to_formatted_s(:db)            # => "2007-01-18 06:10:17"
  #   time.to_formatted_s(:number)        # => "20070118061017"
  #   time.to_formatted_s(:short)         # => "18 Jan 06:10"
  #   time.to_formatted_s(:long)          # => "January 18, 2007 06:10"
  #   time.to_formatted_s(:long_ordinal)  # => "January 18th, 2007 06:10"
  #   time.to_formatted_s(:rfc822)        # => "Thu, 18 Jan 2007 06:10:17 -0600"
  #
  # == Adding your own time formats to +to_formatted_s+
  # You can add your own formats to the Time::DATE_FORMATS hash.
  # Use the format name as the hash key and either a strftime string
  # or Proc instance that takes a time argument as the value.
  #
  #   # config/initializers/time_formats.rb
  #   Time::DATE_FORMATS[:month_and_year] = "%B %Y"
  #   Time::DATE_FORMATS[:short_ordinal] = lambda { |time| time.strftime("%B #{time.day.ordinalize}") }
  def to_formatted_s(format = :default)
    if formatter = DATE_FORMATS[format]
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  # Returns the UTC offset as an +HH:MM formatted string.
  #
  #   Time.local(2000).formatted_offset         # => "-06:00"
  #   Time.local(2000).formatted_offset(false)  # => "-0600"
  def formatted_offset(colon = true, alternate_utc_string = nil)
    utc? && alternate_utc_string || ActiveSupport::TimeZone.seconds_to_utc_offset(utc_offset, colon)
  end

  # Converts a Time object to a Date, dropping hour, minute, and second precision.
  #
  #   my_time = Time.now  # => Mon Nov 12 22:59:51 -0500 2007
  #   my_time.to_date     # => Mon, 12 Nov 2007
  #
  #   your_time = Time.parse("1/13/2009 1:13:03 P.M.")  # => Tue Jan 13 13:13:03 -0500 2009
  #   your_time.to_date                                 # => Tue, 13 Jan 2009
  def to_date
    ::Date.new(year, month, day)
  end unless method_defined?(:to_date)

  # A method to keep Time, Date and DateTime instances interchangeable on conversions.
  # In this case, it simply returns +self+.
  def to_time
    self
  end unless method_defined?(:to_time)

  # Converts a Time instance to a Ruby DateTime instance, preserving UTC offset.
  #
  #   my_time = Time.now    # => Mon Nov 12 23:04:21 -0500 2007
  #   my_time.to_datetime   # => Mon, 12 Nov 2007 23:04:21 -0500
  #
  #   your_time = Time.parse("1/13/2009 1:13:03 P.M.")  # => Tue Jan 13 13:13:03 -0500 2009
  #   your_time.to_datetime                             # => Tue, 13 Jan 2009 13:13:03 -0500
  def to_datetime
    ::DateTime.civil(year, month, day, hour, min, sec, Rational(utc_offset, 86400))
  end unless method_defined?(:to_datetime)
end
