require 'active_support/duration'
require 'active_support/core_ext/numeric/time'

class Integer
  # Enables the use of time calculations and declarations, like <tt>45.minutes +
  # 2.hours + 4.years</tt>.
  #
  # These methods use Time#advance for precise date calculations when using
  # <tt>from_now</tt>, +ago+, etc. as well as adding or subtracting their
  # results from a Time object.
  #
  #   # equivalent to Time.now.advance(months: 1)
  #   1.month.from_now
  #
  #   # equivalent to Time.now.advance(years: 2)
  #   2.years.from_now
  #
  #   # equivalent to Time.now.advance(months: 4, years: 5)
  #   (4.months + 5.years).from_now
  def months
    ActiveSupport::Duration.new(self * 30.days, [[:months, self]])
  end
  alias :month :months

  def years
    ActiveSupport::Duration.new(self * 365.25.days, [[:years, self]])
  end
  alias :year :years
end
