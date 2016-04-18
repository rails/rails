require 'active_support/duration'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date/acts_like'

class Numeric
  # Enables the use of time calculations and declarations, like 45.minutes + 2.hours + 4.years.
  #
  # These methods use Time#advance for precise date calculations when using from_now, ago, etc.
  # as well as adding or subtracting their results from a Time object. For example:
  #
  #   # equivalent to Time.current.advance(months: 1)
  #   1.month.from_now
  #
  #   # equivalent to Time.current.advance(years: 2)
  #   2.years.from_now
  #
  #   # equivalent to Time.current.advance(months: 4, years: 5)
  #   (4.months + 5.years).from_now
  def seconds
    ActiveSupport::Duration.new(self, [[:seconds, self]])
  end
  alias :second :seconds

  # Returns a Duration instance matching the number of minutes provided.
  #
  #   2.minutes # => 2 minutes
  def minutes
    ActiveSupport::Duration.new(self * 60, [[:minutes, self]])
  end
  alias :minute :minutes

  # Returns a Duration instance matching the number of hours provided.
  #
  #   2.hours # => 2 hours
  def hours
    ActiveSupport::Duration.new(self * 3600, [[:hours, self]])
  end
  alias :hour :hours

  # Returns a Duration instance matching the number of days provided.
  #
  #   2.days # => 2 days
  def days
    ActiveSupport::Duration.new(self * 24.hours, [[:days, self]])
  end
  alias :day :days

  # Returns a Duration instance matching the number of weeks provided.
  #
  #   2.weeks # => 2 weeks
  def weeks
    ActiveSupport::Duration.new(self * 7.days, [[:weeks, self]])
  end
  alias :week :weeks

  # Returns a Duration instance matching the number of fortnights provided.
  #
  #   2.fortnights # => 4 weeks
  def fortnights
    ActiveSupport::Duration.new(self * 2.weeks, [[:weeks, self * 2]])
  end
  alias :fortnight :fortnights

  # Returns the number of milliseconds equivalent to the seconds provided.
  # Used with the standard time durations, like 1.hour.in_milliseconds --
  # so we can feed them to JavaScript functions like getTime().
  #
  #   2.in_milliseconds # => 2_000
  def in_milliseconds
    self * 1000
  end
end
