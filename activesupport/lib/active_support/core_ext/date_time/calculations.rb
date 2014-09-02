require 'date'

class DateTime
  class << self
    # Returns <tt>Time.zone.now.to_datetime</tt> when <tt>Time.zone</tt> or
    # <tt>config.time_zone</tt> are set, otherwise returns
    # <tt>Time.now.to_datetime</tt>.
    def current
      ::Time.zone ? ::Time.zone.now.to_datetime : ::Time.now.to_datetime
    end
  end

  # Seconds since midnight: DateTime.now.seconds_since_midnight.
  def seconds_since_midnight
    sec + (min * 60) + (hour * 3600)
  end

  # Returns the number of seconds until 23:59:59.
  #
  #   DateTime.new(2012, 8, 29,  0,  0,  0).seconds_until_end_of_day # => 86399
  #   DateTime.new(2012, 8, 29, 12, 34, 56).seconds_until_end_of_day # => 41103
  #   DateTime.new(2012, 8, 29, 23, 59, 59).seconds_until_end_of_day # => 0
  def seconds_until_end_of_day
    end_of_day.to_i - to_i
  end

  # Returns a new DateTime where one or more of the elements have been changed
  # according to the +options+ parameter. The time options (<tt>:hour</tt>,
  # <tt>:min</tt>, <tt>:sec</tt>) reset cascadingly, so if only the hour is
  # passed, then minute and sec is set to 0. If the hour and minute is passed,
  # then sec is set to 0. The +options+ parameter takes a hash with any of these
  # keys: <tt>:year</tt>, <tt>:month</tt>, <tt>:day</tt>, <tt>:hour</tt>,
  # <tt>:min</tt>, <tt>:sec</tt>, <tt>:offset</tt>, <tt>:start</tt>.
  #
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(day: 1)              # => DateTime.new(2012, 8, 1, 22, 35, 0)
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(year: 1981, day: 1)  # => DateTime.new(1981, 8, 1, 22, 35, 0)
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(year: 1981, hour: 0) # => DateTime.new(1981, 8, 29, 0, 0, 0)
  def change(options)
    ::DateTime.civil(
      options.fetch(:year, year),
      options.fetch(:month, month),
      options.fetch(:day, day),
      options.fetch(:hour, hour),
      options.fetch(:min, options[:hour] ? 0 : min),
      options.fetch(:sec, (options[:hour] || options[:min]) ? 0 : sec + sec_fraction),
      options.fetch(:offset, offset),
      options.fetch(:start, start)
    )
  end

  # Uses Date to provide precise Time calculations for years, months, and days.
  # The +options+ parameter takes a hash with any of these keys: <tt>:years</tt>,
  # <tt>:months</tt>, <tt>:weeks</tt>, <tt>:days</tt>, <tt>:hours</tt>,
  # <tt>:minutes</tt>, <tt>:seconds</tt>.
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
    datetime_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
    seconds_to_advance = \
      options.fetch(:seconds, 0) +
      options.fetch(:minutes, 0) * 60 +
      options.fetch(:hours, 0) * 3600

    if seconds_to_advance.zero?
      datetime_advanced_by_date
    else
      datetime_advanced_by_date.since(seconds_to_advance)
    end
  end

  # Returns a new DateTime representing the time a number of seconds ago.
  # Do not use this method in combination with x.months, use months_ago instead!
  def ago(seconds)
    since(-seconds)
  end

  # Returns a new DateTime representing the time a number of seconds since the
  # instance time. Do not use this method in combination with x.months, use
  # months_since instead!
  def since(seconds)
    self + Rational(seconds.round, 86400)
  end
  alias :in :since

  # Returns a new DateTime representing the start of the day (0:00).
  def beginning_of_day
    change(:hour => 0)
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  # Returns a new DateTime representing the middle of the day (12:00)
  def middle_of_day
    change(:hour => 12)
  end
  alias :midday :middle_of_day
  alias :noon :middle_of_day
  alias :at_midday :middle_of_day
  alias :at_noon :middle_of_day
  alias :at_middle_of_day :middle_of_day

  # Returns a new DateTime representing the end of the day (23:59:59).
  def end_of_day
    change(:hour => 23, :min => 59, :sec => 59)
  end
  alias :at_end_of_day :end_of_day

  # Returns a new DateTime representing the start of the hour (hh:00:00).
  def beginning_of_hour
    change(:min => 0)
  end
  alias :at_beginning_of_hour :beginning_of_hour

  # Returns a new DateTime representing the end of the hour (hh:59:59).
  def end_of_hour
    change(:min => 59, :sec => 59)
  end
  alias :at_end_of_hour :end_of_hour

  # Returns a new DateTime representing the start of the minute (hh:mm:00).
  def beginning_of_minute
    change(:sec => 0)
  end
  alias :at_beginning_of_minute :beginning_of_minute

  # Returns a new DateTime representing the end of the minute (hh:mm:59).
  def end_of_minute
    change(:sec => 59)
  end
  alias :at_end_of_minute :end_of_minute

  # Adjusts DateTime to UTC by adding its offset value; offset is set to 0.
  #
  #   DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24))     # => Mon, 21 Feb 2005 10:11:12 -0600
  #   DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24)).utc # => Mon, 21 Feb 2005 16:11:12 +0000
  def utc
    new_offset(0)
  end
  alias_method :getutc, :utc

  # Returns +true+ if <tt>offset == 0</tt>.
  def utc?
    offset == 0
  end

  # Returns the offset value in seconds.
  def utc_offset
    (offset * 86400).to_i
  end

  # Layers additional behavior on DateTime#<=> so that Time and
  # ActiveSupport::TimeWithZone instances can be compared with a DateTime.
  def <=>(other)
    if other.kind_of?(Infinity)
      super
    elsif other.respond_to? :to_datetime
      super other.to_datetime
    else
      nil
    end
  end

end
