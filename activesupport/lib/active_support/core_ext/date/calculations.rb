require 'date'
require 'active_support/duration'
require 'active_support/core_ext/object/acts_like'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/time/zones'

class Date
  DAYS_INTO_WEEK = {
    :monday => 0,
    :tuesday => 1,
    :wednesday => 2,
    :thursday => 3,
    :friday => 4,
    :saturday => 5,
    :sunday => 6
  }

  class << self
    # Returns a new Date representing the date 1 day ago (i.e. yesterday's date).
    def yesterday
      ::Date.current.yesterday
    end

    # Returns a new Date representing the date 1 day after today (i.e. tomorrow's date).
    def tomorrow
      ::Date.current.tomorrow
    end

    # Returns Time.zone.today when <tt>Time.zone</tt> or <tt>config.time_zone</tt> are set, otherwise just returns Date.today.
    def current
      ::Time.zone ? ::Time.zone.today : ::Date.today
    end
  end

  # Returns true if the Date object's date lies in the past. Otherwise returns false.
  def past?
    self < ::Date.current
  end

  # Returns true if the Date object's date is today.
  def today?
    to_date == ::Date.current # we need the to_date because of DateTime
  end

  # Returns true if the Date object's date lies in the future.
  def future?
    self > ::Date.current
  end

  # Converts Date to a Time (or DateTime if necessary) with the time portion set to the beginning of the day (0:00)
  # and then subtracts the specified number of seconds.
  def ago(seconds)
    to_time_in_current_zone.since(-seconds)
  end

  # Converts Date to a Time (or DateTime if necessary) with the time portion set to the beginning of the day (0:00)
  # and then adds the specified number of seconds
  def since(seconds)
    to_time_in_current_zone.since(seconds)
  end
  alias :in :since

  # Converts Date to a Time (or DateTime if necessary) with the time portion set to the beginning of the day (0:00)
  def beginning_of_day
    to_time_in_current_zone
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  # Converts Date to a Time (or DateTime if necessary) with the time portion set to the end of the day (23:59:59)
  def end_of_day
    to_time_in_current_zone.end_of_day
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
      plus_with_duration(-other)
    else
      minus_without_duration(other)
    end
  end
  alias_method :minus_without_duration, :-
  alias_method :-, :minus_with_duration

  # Provides precise Date calculations for years, months, and days. The +options+ parameter takes a hash with
  # any of these keys: <tt>:years</tt>, <tt>:months</tt>, <tt>:weeks</tt>, <tt>:days</tt>.
  def advance(options)
    options = options.dup
    d = self
    d = d >> options.delete(:years) * 12 if options[:years]
    d = d >> options.delete(:months)     if options[:months]
    d = d +  options.delete(:weeks) * 7  if options[:weeks]
    d = d +  options.delete(:days)       if options[:days]
    d
  end

  # Returns a new Date where one or more of the elements have been changed according to the +options+ parameter.
  #
  #   Date.new(2007, 5, 12).change(:day => 1)                  # => Date.new(2007, 5, 1)
  #   Date.new(2007, 5, 12).change(:year => 2005, :month => 1) # => Date.new(2005, 1, 12)
  def change(options)
    ::Date.new(
      options.fetch(:year, year),
      options.fetch(:month, month),
      options.fetch(:day, day)
    )
  end

  # Returns a new Date/DateTime representing the time a number of specified weeks ago.
  def weeks_ago(weeks)
    advance(:weeks => -weeks)
  end

  # Returns a new Date/DateTime representing the time a number of specified months ago.
  def months_ago(months)
    advance(:months => -months)
  end

  # Returns a new Date/DateTime representing the time a number of specified months in the future.
  def months_since(months)
    advance(:months => months)
  end

  # Returns a new Date/DateTime representing the time a number of specified years ago.
  def years_ago(years)
    advance(:years => -years)
  end

  # Returns a new Date/DateTime representing the time a number of specified years in the future.
  def years_since(years)
    advance(:years => years)
  end

  # Returns number of days to start of this week. Week is assumed to start on
  # +start_day+, default is +:monday+.
  def days_to_week_start(start_day = :monday)
    start_day_number = DAYS_INTO_WEEK[start_day]
    current_day_number = wday != 0 ? wday - 1 : 6
    (current_day_number - start_day_number) % 7
  end

  # Returns a new +Date+/+DateTime+ representing the start of this week. Week is
  # assumed to start on +start_day+, default is +:monday+. +DateTime+ objects
  # have their time set to 0:00.
  def beginning_of_week(start_day = :monday)
    days_to_start = days_to_week_start(start_day)
    result = self - days_to_start
    acts_like?(:time) ? result.midnight : result
  end
  alias :at_beginning_of_week :beginning_of_week

  # Returns a new +Date+/+DateTime+ representing the start of this week. Week is
  # assumed to start on a Monday. +DateTime+ objects have their time set to 0:00.
  def monday
    beginning_of_week
  end

  # Returns a new +Date+/+DateTime+ representing the end of this week. Week is
  # assumed to start on +start_day+, default is +:monday+. +DateTime+ objects
  # have their time set to 23:59:59.
  def end_of_week(start_day = :monday)
    days_to_end = 6 - days_to_week_start(start_day)
    result = self + days_to_end.days
    acts_like?(:time) ? result.end_of_day : result
  end
  alias :at_end_of_week :end_of_week

  # Returns a new +Date+/+DateTime+ representing the end of this week. Week is
  # assumed to start on a Monday. +DateTime+ objects have their time set to 23:59:59.
  def sunday
    end_of_week
  end

  # Returns a new +Date+/+DateTime+ representing the given +day+ in the previous
  # week. Default is +:monday+. +DateTime+ objects have their time set to 0:00.
  def prev_week(day = :monday)
    result = (self - 7).beginning_of_week + DAYS_INTO_WEEK[day]
    acts_like?(:time) ? result.change(:hour => 0) : result
  end
  alias :last_week :prev_week

  # Alias of prev_month
  alias :last_month :prev_month

  # Alias of prev_year
  alias :last_year :prev_year

  # Returns a new Date/DateTime representing the start of the given day in next week (default is :monday).
  def next_week(day = :monday)
    result = (self + 7).beginning_of_week + DAYS_INTO_WEEK[day]
    acts_like?(:time) ? result.change(:hour => 0) : result
  end

  # Short-hand for months_ago(3)
  def prev_quarter
    months_ago(3)
  end
  alias_method :last_quarter, :prev_quarter

  # Short-hand for months_since(3)
  def next_quarter
    months_since(3)
  end

  # Returns a new Date/DateTime representing the start of the month (1st of the month; DateTime objects will have time set to 0:00)
  def beginning_of_month
    acts_like?(:time) ? change(:day => 1, :hour => 0) : change(:day => 1)
  end
  alias :at_beginning_of_month :beginning_of_month

  # Returns a new Date/DateTime representing the end of the month (last day of the month; DateTime objects will have time set to 0:00)
  def end_of_month
    last_day = ::Time.days_in_month(month, year)
    if acts_like?(:time)
      change(:day => last_day, :hour => 23, :min => 59, :sec => 59)
    else
      change(:day => last_day)
    end
  end
  alias :at_end_of_month :end_of_month

  # Returns a new Date/DateTime representing the start of the quarter (1st of january, april, july, october; DateTime objects will have time set to 0:00)
  def beginning_of_quarter
    first_quarter_month = [10, 7, 4, 1].detect { |m| m <= month }
    beginning_of_month.change(:month => first_quarter_month)
  end
  alias :at_beginning_of_quarter :beginning_of_quarter

  # Returns a new Date/DateTime representing the end of the quarter (last day of march, june, september, december; DateTime objects will have time set to 23:59:59)
  def end_of_quarter
    last_quarter_month = [3, 6, 9, 12].detect { |m| m >= month }
    beginning_of_month.change(:month => last_quarter_month).end_of_month
  end
  alias :at_end_of_quarter :end_of_quarter

  # Returns a new Date/DateTime representing the start of the year (1st of january; DateTime objects will have time set to 0:00)
  def beginning_of_year
    if acts_like?(:time)
      change(:month => 1, :day => 1, :hour => 0)
    else
      change(:month => 1, :day => 1)
    end
  end
  alias :at_beginning_of_year :beginning_of_year

  # Returns a new Time representing the end of the year (31st of december; DateTime objects will have time set to 23:59:59)
  def end_of_year
    if acts_like?(:time)
      change(:month => 12, :day => 31, :hour => 23, :min => 59, :sec => 59)
    else
      change(:month => 12, :day => 31)
    end
  end
  alias :at_end_of_year :end_of_year

  # Convenience method which returns a new Date/DateTime representing the time 1 day ago
  def yesterday
    self - 1
  end

  # Convenience method which returns a new Date/DateTime representing the time 1 day since the instance time
  def tomorrow
    self + 1
  end
end
