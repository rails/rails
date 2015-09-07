require 'active_support/duration'
require 'active_support/core_ext/time/conversions'
require 'active_support/time_with_zone'
require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/date_and_time/calculations'
require 'active_support/core_ext/date/calculations'

class Time
  include DateAndTime::Calculations

  COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

  class << self
    # Overriding case equality method so that it returns true for ActiveSupport::TimeWithZone instances
    def ===(other)
      super || (self == Time && other.is_a?(ActiveSupport::TimeWithZone))
    end

    # Return the number of days in the given month.
    # If no year is specified, it will use the current year.
    def days_in_month(month, year = now.year)
      if month == 2 && ::Date.gregorian_leap?(year)
        29
      else
        COMMON_YEAR_DAYS_IN_MONTH[month]
      end
    end

    # Returns <tt>Time.zone.now</tt> when <tt>Time.zone</tt> or <tt>config.time_zone</tt> are set, otherwise just returns <tt>Time.now</tt>.
    def current
      ::Time.zone ? ::Time.zone.now : ::Time.now
    end

    # Layers additional behavior on Time.at so that ActiveSupport::TimeWithZone and DateTime
    # instances can be used when called with a single argument
    def at_with_coercion(*args)
      return at_without_coercion(*args) if args.size != 1

      # Time.at can be called with a time or numerical value
      time_or_number = args.first

      if time_or_number.is_a?(ActiveSupport::TimeWithZone) || time_or_number.is_a?(DateTime)
        at_without_coercion(time_or_number.to_f).getlocal
      else
        at_without_coercion(time_or_number)
      end
    end
    alias_method :at_without_coercion, :at
    alias_method :at, :at_with_coercion
  end

  # Seconds since midnight: Time.now.seconds_since_midnight
  def seconds_since_midnight
    to_i - change(:hour => 0).to_i + (usec / 1.0e+6)
  end

  # Returns the number of seconds until 23:59:59.
  #
  #   Time.new(2012, 8, 29,  0,  0,  0).seconds_until_end_of_day # => 86399
  #   Time.new(2012, 8, 29, 12, 34, 56).seconds_until_end_of_day # => 41103
  #   Time.new(2012, 8, 29, 23, 59, 59).seconds_until_end_of_day # => 0
  def seconds_until_end_of_day
    end_of_day.to_i - to_i
  end

  # Returns a new Time where one or more of the elements have been changed according
  # to the +options+ parameter. The time options (<tt>:hour</tt>, <tt>:min</tt>,
  # <tt>:sec</tt>, <tt>:usec</tt>, <tt>:nsec</tt>) reset cascadingly, so if only
  # the hour is passed, then minute, sec, usec and nsec is set to 0. If the hour
  # and minute is passed, then sec, usec and nsec is set to 0. The +options+
  # parameter takes a hash with any of these keys: <tt>:year</tt>, <tt>:month</tt>,
  # <tt>:day</tt>, <tt>:hour</tt>, <tt>:min</tt>, <tt>:sec</tt>, <tt>:usec</tt>
  # <tt>:nsec</tt>. Path either <tt>:usec</tt> or <tt>:nsec</tt>, not both.
  #
  #   Time.new(2012, 8, 29, 22, 35, 0).change(day: 1)              # => Time.new(2012, 8, 1, 22, 35, 0)
  #   Time.new(2012, 8, 29, 22, 35, 0).change(year: 1981, day: 1)  # => Time.new(1981, 8, 1, 22, 35, 0)
  #   Time.new(2012, 8, 29, 22, 35, 0).change(year: 1981, hour: 0) # => Time.new(1981, 8, 29, 0, 0, 0)
  def change(options)
    new_year  = options.fetch(:year, year)
    new_month = options.fetch(:month, month)
    new_day   = options.fetch(:day, day)
    new_hour  = options.fetch(:hour, hour)
    new_min   = options.fetch(:min, options[:hour] ? 0 : min)
    new_sec   = options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec)

    if new_nsec = options[:nsec]
      raise ArgumentError, "Can't change both :nsec and :usec at the same time: #{options.inspect}" if options[:usec]
      new_usec = Rational(new_nsec, 1000)
    else
      new_usec  = options.fetch(:usec, (options[:hour] || options[:min] || options[:sec]) ? 0 : Rational(nsec, 1000))
    end

    if utc?
      ::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    elsif zone
      ::Time.local(new_year, new_month, new_day, new_hour, new_min, new_sec, new_usec)
    else
      raise ArgumentError, 'argument out of range' if new_usec >= 1000000
      ::Time.new(new_year, new_month, new_day, new_hour, new_min, new_sec + (new_usec.to_r / 1000000), utc_offset)
    end
  end

  # Uses Date to provide precise Time calculations for years, months, and days
  # according to the proleptic Gregorian calendar. The +options+ parameter
  # takes a hash with any of these keys: <tt>:years</tt>, <tt>:months</tt>,
  # <tt>:weeks</tt>, <tt>:days</tt>, <tt>:hours</tt>, <tt>:minutes</tt>,
  # <tt>:seconds</tt>.
  #
  #   Time.new(2015, 8, 1, 14, 35, 0).advance(seconds: 1) # => 2015-08-01 14:35:01 -0700
  #   Time.new(2015, 8, 1, 14, 35, 0).advance(minutes: 1) # => 2015-08-01 14:36:00 -0700
  #   Time.new(2015, 8, 1, 14, 35, 0).advance(hours: 1)   # => 2015-08-01 15:35:00 -0700
  #   Time.new(2015, 8, 1, 14, 35, 0).advance(days: 1)    # => 2015-08-02 14:35:00 -0700
  #   Time.new(2015, 8, 1, 14, 35, 0).advance(weeks: 1)   # => 2015-08-08 14:35:00 -0700
  def advance(options)
    unless options[:weeks].nil?
      options[:weeks], partial_weeks = options[:weeks].divmod(1)
      options[:days] = options.fetch(:days, 0) + 7 * partial_weeks
    end

    unless options[:days].nil?
      options[:days], partial_days = options[:days].divmod(1)
      options[:hours] = options.fetch(:hours, 0) + 24 * partial_days
    end

    d = to_date.advance(options)
    d = d.gregorian if d.julian?
    time_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = \
      options.fetch(:seconds, 0) +
      options.fetch(:minutes, 0) * 60 +
      options.fetch(:hours, 0) * 3600

    if seconds_to_advance.zero?
      time_advanced_by_date
    else
      time_advanced_by_date.since(seconds_to_advance)
    end
  end

  # Returns a new Time representing the time a number of seconds ago, this is basically a wrapper around the Numeric extension
  def ago(seconds)
    since(-seconds)
  end

  # Returns a new Time representing the time a number of seconds since the instance time
  def since(seconds)
    self + seconds
  rescue
    to_datetime.since(seconds)
  end
  alias :in :since

  # Returns a new Time representing the start of the day (0:00)
  def beginning_of_day
    #(self - seconds_since_midnight).change(usec: 0)
    change(:hour => 0)
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  # Returns a new Time representing the middle of the day (12:00)
  def middle_of_day
    change(:hour => 12)
  end
  alias :midday :middle_of_day
  alias :noon :middle_of_day
  alias :at_midday :middle_of_day
  alias :at_noon :middle_of_day
  alias :at_middle_of_day :middle_of_day

  # Returns a new Time representing the end of the day, 23:59:59.999999 (.999999999 in ruby1.9)
  def end_of_day
    change(
      :hour => 23,
      :min => 59,
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_day :end_of_day

  # Returns a new Time representing the start of the hour (x:00)
  def beginning_of_hour
    change(:min => 0)
  end
  alias :at_beginning_of_hour :beginning_of_hour

  # Returns a new Time representing the end of the hour, x:59:59.999999 (.999999999 in ruby1.9)
  def end_of_hour
    change(
      :min => 59,
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_hour :end_of_hour

  # Returns a new Time representing the start of the minute (x:xx:00)
  def beginning_of_minute
    change(:sec => 0)
  end
  alias :at_beginning_of_minute :beginning_of_minute

  # Returns a new Time representing the end of the minute, x:xx:59.999999 (.999999999 in ruby1.9)
  def end_of_minute
    change(
      :sec => 59,
      :usec => Rational(999999999, 1000)
    )
  end
  alias :at_end_of_minute :end_of_minute

  # Returns a Range representing the whole day of the current time.
  def all_day
    beginning_of_day..end_of_day
  end

  def plus_with_duration(other) #:nodoc:
    if ActiveSupport::Duration === other
      other.since(self)
    else
      plus_without_duration(other)
    end
  end
  alias_method :plus_without_duration, :+
  alias_method :+, :plus_with_duration

  def minus_with_duration(other) #:nodoc:
    if ActiveSupport::Duration === other
      other.until(self)
    else
      minus_without_duration(other)
    end
  end
  alias_method :minus_without_duration, :-
  alias_method :-, :minus_with_duration

  # Time#- can also be used to determine the number of seconds between two Time instances.
  # We're layering on additional behavior so that ActiveSupport::TimeWithZone instances
  # are coerced into values that Time#- will recognize
  def minus_with_coercion(other)
    other = other.comparable_time if other.respond_to?(:comparable_time)
    other.is_a?(DateTime) ? to_f - other.to_f : minus_without_coercion(other)
  end
  alias_method :minus_without_coercion, :-
  alias_method :-, :minus_with_coercion

  # Layers additional behavior on Time#<=> so that DateTime and ActiveSupport::TimeWithZone instances
  # can be chronologically compared with a Time
  def compare_with_coercion(other)
    # we're avoiding Time#to_datetime cause it's expensive
    if other.is_a?(Time)
      compare_without_coercion(other.to_time)
    else
      to_datetime <=> other
    end
  end
  alias_method :compare_without_coercion, :<=>
  alias_method :<=>, :compare_with_coercion

  # Layers additional behavior on Time#eql? so that ActiveSupport::TimeWithZone instances
  # can be eql? to an equivalent Time
  def eql_with_coercion(other)
    # if other is an ActiveSupport::TimeWithZone, coerce a Time instance from it so we can do eql? comparison
    other = other.comparable_time if other.respond_to?(:comparable_time)
    eql_without_coercion(other)
  end
  alias_method :eql_without_coercion, :eql?
  alias_method :eql?, :eql_with_coercion

end
