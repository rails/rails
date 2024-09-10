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
  #
  # While these methods provide precise calculation when used as in the examples
  # above, care should be taken to note that this is not true if the result of
  # +months+, +years+, etc is converted before use:
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
  def months
    ActiveSupport::Duration.new(30.days * self, [[:months, self]])
  end
  alias :month :months

  def years
    ActiveSupport::Duration.new(365.25.days * self, [[:years, self]])
  end
  alias :year :years
end
