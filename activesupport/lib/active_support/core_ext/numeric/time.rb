require 'active_support/duration'
require 'active_support/core_ext/time/calculations'
require 'active_support/core_ext/time/acts_like'

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
  #
  # While these methods provide precise calculation when used as in the examples above, care
  # should be taken to note that this is not true if the result of `months', `years', etc is
  # converted before use:
  #
  #   # equivalent to 30.days.to_i.from_now
  #   1.month.to_i.from_now
  #
  #   # equivalent to 365.25.days.to_f.from_now
  #   1.year.to_f.from_now
  #
  # In such cases, Ruby's core
  # Date[http://ruby-doc.org/stdlib/libdoc/date/rdoc/Date.html] and
  # Time[http://ruby-doc.org/stdlib/libdoc/time/rdoc/Time.html] should be used for precision
  # date and time arithmetic.
  def seconds
    ActiveSupport::Duration.new(self, [[:seconds, self]])
  end
  alias :second :seconds

  def minutes
    ActiveSupport::Duration.new(self * 60, [[:seconds, self * 60]])
  end
  alias :minute :minutes

  def hours
    ActiveSupport::Duration.new(self * 3600, [[:seconds, self * 3600]])
  end
  alias :hour :hours

  def days
    ActiveSupport::Duration.new(self * 24.hours, [[:days, self]])
  end
  alias :day :days

  def weeks
    ActiveSupport::Duration.new(self * 7.days, [[:days, self * 7]])
  end
  alias :week :weeks

  def fortnights
    ActiveSupport::Duration.new(self * 2.weeks, [[:days, self * 14]])
  end
  alias :fortnight :fortnights

  # Reads best without arguments:  10.minutes.ago
  def ago(time = ::Time.current)
    ActiveSupport::Deprecation.warn "Calling #ago or #until on a number (e.g. 5.ago) is deprecated and will be removed in the future, use 5.seconds.ago instead"
    time - self
  end

  # Reads best with argument:  10.minutes.until(time)
  alias :until :ago

  # Reads best with argument:  10.minutes.since(time)
  def since(time = ::Time.current)
    ActiveSupport::Deprecation.warn "Calling #since or #from_now on a number (e.g. 5.since) is deprecated and will be removed in the future, use 5.seconds.since instead"
    time + self
  end

  # Reads best without arguments:  10.minutes.from_now
  alias :from_now :since

  # Used with the standard time durations, like 1.hour.in_milliseconds -- 
  # so we can feed them to JavaScript functions like getTime().
  def in_milliseconds
    self * 1000
  end
end
