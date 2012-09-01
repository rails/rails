require 'date'
require 'active_support/duration'
require 'active_support/core_ext/object/acts_like'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/date_and_time/calculations'

class Date
  include DateAndTime::Calculations

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
  # The +options+ parameter is a hash with a combination of these keys: <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>.
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
end
