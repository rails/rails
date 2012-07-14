require 'active_support/duration'
require 'active_support/core_ext/time/conversions'
require 'active_support/time_with_zone'
require 'active_support/core_ext/time/zones'

class Time
  COMMON_YEAR_DAYS_IN_MONTH = [nil, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  DAYS_INTO_WEEK = { :monday => 0, :tuesday => 1, :wednesday => 2, :thursday => 3, :friday => 4, :saturday => 5, :sunday => 6 }

  class << self
    # Overriding case equality method so that it returns true for ActiveSupport::TimeWithZone instances
    def ===(other)
      super || (self == Time && other.is_a?(ActiveSupport::TimeWithZone))
    end

    # Return the number of days in the given month.
    # If no year is specified, it will use the current year.
    def days_in_month(month, year = now.year)
      return 29 if month == 2 && ::Date.gregorian_leap?(year)
      COMMON_YEAR_DAYS_IN_MONTH[month]
    end

    # Returns a new Time if requested year can be accommodated by Ruby's Time class
    # (i.e., if year is within either 1970..2038 or 1902..2038, depending on system architecture);
    # otherwise returns a DateTime.
    def time_with_datetime_fallback(utc_or_local, year, month=1, day=1, hour=0, min=0, sec=0, usec=0)
      time = ::Time.send(utc_or_local, year, month, day, hour, min, sec, usec)
      # This check is needed because Time.utc(y) returns a time object in the 2000s for 0 <= y <= 138.
      time.year == year ? time : ::DateTime.civil_from_format(utc_or_local, year, month, day, hour, min, sec)
    rescue
      ::DateTime.civil_from_format(utc_or_local, year, month, day, hour, min, sec)
    end

    # Wraps class method +time_with_datetime_fallback+ with +utc_or_local+ set to <tt>:utc</tt>.
    def utc_time(*args)
      time_with_datetime_fallback(:utc, *args)
    end

    # Wraps class method +time_with_datetime_fallback+ with +utc_or_local+ set to <tt>:local</tt>.
    def local_time(*args)
      time_with_datetime_fallback(:local, *args)
    end

    # Returns <tt>Time.zone.now</tt> when <tt>Time.zone</tt> or <tt>config.time_zone</tt> are set, otherwise just returns <tt>Time.now</tt>.
    def current
      ::Time.zone ? ::Time.zone.now : ::Time.now
    end
  end

  # Tells whether the Time object's time lies in the past
  def past?
    self < ::Time.current
  end

  # Tells whether the Time object's time is today
  def today?
    to_date == ::Date.current
  end

  # Tells whether the Time object's time lies in the future
  def future?
    self > ::Time.current
  end

  # Seconds since midnight: Time.now.seconds_since_midnight
  def seconds_since_midnight
    to_i - change(:hour => 0).to_i + (usec / 1.0e+6)
  end

  # Returns a new Time where one or more of the elements have been changed according to the +options+ parameter. The time options
  # (hour, min, sec, usec) reset cascadingly, so if only the hour is passed, then minute, sec, and usec is set to 0. If the hour and
  # minute is passed, then sec and usec is set to 0.
  def change(options)
    ::Time.send(
      utc? ? :utc_time : :local_time,
      options[:year]  || year,
      options[:month] || month,
      options[:day]   || day,
      options[:hour]  || hour,
      options[:min]   || (options[:hour] ? 0 : min),
      options[:sec]   || ((options[:hour] || options[:min]) ? 0 : sec),
      options[:usec]  || ((options[:hour] || options[:min] || options[:sec]) ? 0 : usec)
    )
  end

  # Uses Date to provide precise Time calculations for years, months, and days.
  # The +options+ parameter takes a hash with any of these keys: <tt>:years</tt>,
  # <tt>:months</tt>, <tt>:weeks</tt>, <tt>:days</tt>, <tt>:hours</tt>,
  # <tt>:minutes</tt>, <tt>:seconds</tt>.
  def advance(options)
    unless options[:weeks].nil?
      options[:weeks], partial_weeks = options[:weeks].divmod(1)
      options[:days] = (options[:days] || 0) + 7 * partial_weeks
    end

    unless options[:days].nil?
      options[:days], partial_days = options[:days].divmod(1)
      options[:hours] = (options[:hours] || 0) + 24 * partial_days
    end

    d = to_date.advance(options)
    time_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = (options[:seconds] || 0) + (options[:minutes] || 0) * 60 + (options[:hours] || 0) * 3600
    seconds_to_advance == 0 ? time_advanced_by_date : time_advanced_by_date.since(seconds_to_advance)
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

  # Returns a new Time representing the time a number of specified weeks ago.
  def weeks_ago(weeks)
    advance(:weeks => -weeks)
  end

  # Returns a new Time representing the time a number of specified months ago
  def months_ago(months)
    advance(:months => -months)
  end

  # Returns a new Time representing the time a number of specified months in the future
  def months_since(months)
    advance(:months => months)
  end

  # Returns a new Time representing the time a number of specified years ago
  def years_ago(years)
    advance(:years => -years)
  end

  # Returns a new Time representing the time a number of specified years in the future
  def years_since(years)
    advance(:years => years)
  end

  # Short-hand for years_ago(1)
  def prev_year
    years_ago(1)
  end

  # Short-hand for years_since(1)
  def next_year
    years_since(1)
  end

  # Short-hand for months_ago(1)
  def prev_month
    months_ago(1)
  end

  # Short-hand for months_since(1)
  def next_month
    months_since(1)
  end

  # Returns number of days to start of this week, week starts on start_day (default is :monday).
  def days_to_week_start(start_day = :monday)
    start_day_number = DAYS_INTO_WEEK[start_day]
    current_day_number = wday != 0 ? wday - 1 : 6
    days_span = current_day_number - start_day_number
    days_span >= 0 ? days_span : 7 + days_span
  end

  # Returns a new Time representing the "start" of this week, week starts on start_day (default is :monday, i.e. Monday, 0:00).
  def beginning_of_week(start_day = :monday)
    days_to_start = days_to_week_start(start_day)
    (self - days_to_start.days).midnight
  end
  alias :at_beginning_of_week :beginning_of_week

  # Returns a new +Date+/+DateTime+ representing the start of this week. Week is
  # assumed to start on a Monday. +DateTime+ objects have their time set to 0:00.
  def monday
    beginning_of_week
  end

  # Returns a new Time representing the end of this week, week starts on start_day (default is :monday, i.e. end of Sunday).
  def end_of_week(start_day = :monday)
    days_to_end =  6 - days_to_week_start(start_day)
    (self + days_to_end.days).end_of_day
  end
  alias :at_end_of_week :end_of_week

  # Returns a new +Date+/+DateTime+ representing the end of this week. Week is
  # assumed to start on a Monday. +DateTime+ objects have their time set to 23:59:59.
  def sunday
    end_of_week
  end

  # Returns a new Time representing the start of the given day in the previous week (default is :monday).
  def prev_week(day = :monday)
    ago(1.week).beginning_of_week.since(DAYS_INTO_WEEK[day].day).change(:hour => 0)
  end

  # Returns a new Time representing the start of the given day in next week (default is :monday).
  def next_week(day = :monday)
    since(1.week).beginning_of_week.since(DAYS_INTO_WEEK[day].day).change(:hour => 0)
  end

  # Returns a new Time representing the start of the day (0:00)
  def beginning_of_day
    #(self - seconds_since_midnight).change(:usec => 0)
    change(:hour => 0)
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  # Returns a new Time representing the end of the day, 23:59:59.999999 (.999999999 in ruby1.9)
  def end_of_day
    change(:hour => 23, :min => 59, :sec => 59, :usec => 999999.999)
  end

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
      :usec => 999999.999
    )
  end

  # Returns a new Time representing the start of the month (1st of the month, 0:00)
  def beginning_of_month
    #self - ((self.mday-1).days + self.seconds_since_midnight)
    change(:day => 1, :hour => 0)
  end
  alias :at_beginning_of_month :beginning_of_month

  # Returns a new Time representing the end of the month (end of the last day of the month)
  def end_of_month
    #self - ((self.mday-1).days + self.seconds_since_midnight)
    last_day = ::Time.days_in_month(month, year)
    change(:day => last_day, :hour => 23, :min => 59, :sec => 59, :usec => 999999.999)
  end
  alias :at_end_of_month :end_of_month

  # Returns  a new Time representing the start of the quarter (1st of january, april, july, october, 0:00)
  def beginning_of_quarter
    beginning_of_month.change(:month => [10, 7, 4, 1].detect { |m| m <= month })
  end
  alias :at_beginning_of_quarter :beginning_of_quarter

  # Returns a new Time representing the end of the quarter (end of the last day of march, june, september, december)
  def end_of_quarter
    beginning_of_month.change(:month => [3, 6, 9, 12].detect { |m| m >= month }).end_of_month
  end
  alias :at_end_of_quarter :end_of_quarter

  # Returns a new Time representing the start of the year (1st of january, 0:00)
  def beginning_of_year
    change(:month => 1, :day => 1, :hour => 0)
  end
  alias :at_beginning_of_year :beginning_of_year

  # Returns a new Time representing the end of the year (end of the 31st of december)
  def end_of_year
    change(:month => 12, :day => 31, :hour => 23, :min => 59, :sec => 59, :usec => 999999.999)
  end
  alias :at_end_of_year :end_of_year

  # Convenience method which returns a new Time representing the time 1 day ago
  def yesterday
    advance(:days => -1)
  end

  # Convenience method which returns a new Time representing the time 1 day since the instance time
  def tomorrow
    advance(:days => 1)
  end

  # Returns a Range representing the whole day of the current time.
  def all_day
    beginning_of_day..end_of_day
  end

  # Returns a Range representing the whole week of the current time. Week starts on start_day (default is :monday, i.e. end of Sunday).
  def all_week(start_day = :monday)
    beginning_of_week(start_day)..end_of_week(start_day)
  end

  # Returns a Range representing the whole month of the current time.
  def all_month
    beginning_of_month..end_of_month
  end

  # Returns a Range representing the whole quarter of the current time.
  def all_quarter
    beginning_of_quarter..end_of_quarter
  end

  # Returns a Range representing the whole year of the current time.
  def all_year
    beginning_of_year..end_of_year
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
    other.is_a?(Time) ? compare_without_coercion(other.to_time) : to_datetime <=> other
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
