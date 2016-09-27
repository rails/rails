require "date"

class DateTime
  class << self
    # Returns <tt>Time.zone.now.to_datetime</tt> when <tt>Time.zone</tt> or
    # <tt>config.time_zone</tt> are set, otherwise returns
    # <tt>Time.now.to_datetime</tt>.
    def current
      ::Time.zone ? ::Time.zone.now.to_datetime : ::Time.now.to_datetime
    end
  end

  # Returns the number of seconds since 00:00:00.
  #
  #   DateTime.new(2012, 8, 29,  0,  0,  0).seconds_since_midnight # => 0
  #   DateTime.new(2012, 8, 29, 12, 34, 56).seconds_since_midnight # => 45296
  #   DateTime.new(2012, 8, 29, 23, 59, 59).seconds_since_midnight # => 86399
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

  # Returns the fraction of a second as a +Rational+
  #
  #   DateTime.new(2012, 8, 29, 0, 0, 0.5).subsec # => (1/2)
  def subsec
    sec_fraction
  end

  # Returns a new DateTime where one or more of the elements have been changed
  # according to the parameters. The time options (<tt>:hour</tt>,
  # <tt>:min</tt>, <tt>:sec</tt>) reset cascadingly, so if only the hour is
  # passed, then minute and sec is set to 0. If the hour and minute is passed,
  # then sec is set to 0.
  #
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(day: 1)              # => DateTime.new(2012, 8, 1, 22, 35, 0)
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(year: 1981, day: 1)  # => DateTime.new(1981, 8, 1, 22, 35, 0)
  #   DateTime.new(2012, 8, 29, 22, 35, 0).change(year: 1981, hour: 0) # => DateTime.new(1981, 8, 29, 0, 0, 0)
  def change(year: nil, month: nil, day: nil, hour: nil, min: nil, sec: nil, offset: nil, start: nil)
    ::DateTime.civil(
      year || self.year,
      month || self.month,
      day || self.day,
      hour || self.hour,
      min || (hour ? 0 : self.min),
      sec || ((hour || min) ? 0 : self.sec + sec_fraction),
      offset || self.offset,
      start || self.start
    )
  end

  # Uses Date to provide precise Time calculations for years, months, and days.
  def advance(years: nil, months: nil, weeks: nil, days: nil, hours: nil, minutes: nil, seconds: nil)
    unless weeks.nil?
      weeks, partial_weeks = weeks.divmod(1)
      days = (days || 0) + 7 * partial_weeks
    end

    unless days.nil?
      days, partial_days = days.divmod(1)
      hours = (hours || 0) + 24 * partial_days
    end

    d = to_date.advance(years: years, months: months, weeks: weeks, days: days)
    datetime_advanced_by_date = change(year: d.year, month: d.month, day: d.day)
    seconds_to_advance = \
      (seconds || 0) +
      (minutes || 0) * 60 +
      (hours || 0) * 3600

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
    change(hour: 0)
  end
  alias :midnight :beginning_of_day
  alias :at_midnight :beginning_of_day
  alias :at_beginning_of_day :beginning_of_day

  # Returns a new DateTime representing the middle of the day (12:00)
  def middle_of_day
    change(hour: 12)
  end
  alias :midday :middle_of_day
  alias :noon :middle_of_day
  alias :at_midday :middle_of_day
  alias :at_noon :middle_of_day
  alias :at_middle_of_day :middle_of_day

  # Returns a new DateTime representing the end of the day (23:59:59).
  def end_of_day
    change(hour: 23, min: 59, sec: 59)
  end
  alias :at_end_of_day :end_of_day

  # Returns a new DateTime representing the start of the hour (hh:00:00).
  def beginning_of_hour
    change(min: 0)
  end
  alias :at_beginning_of_hour :beginning_of_hour

  # Returns a new DateTime representing the end of the hour (hh:59:59).
  def end_of_hour
    change(min: 59, sec: 59)
  end
  alias :at_end_of_hour :end_of_hour

  # Returns a new DateTime representing the start of the minute (hh:mm:00).
  def beginning_of_minute
    change(sec: 0)
  end
  alias :at_beginning_of_minute :beginning_of_minute

  # Returns a new DateTime representing the end of the minute (hh:mm:59).
  def end_of_minute
    change(sec: 59)
  end
  alias :at_end_of_minute :end_of_minute

  # Returns a <tt>Time</tt> instance of the simultaneous time in the system timezone.
  def localtime(utc_offset = nil)
    utc = new_offset(0)

    Time.utc(
      utc.year, utc.month, utc.day,
      utc.hour, utc.min, utc.sec + utc.sec_fraction
    ).getlocal(utc_offset)
  end
  alias_method :getlocal, :localtime

  # Returns a <tt>Time</tt> instance of the simultaneous time in the UTC timezone.
  #
  #   DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24))     # => Mon, 21 Feb 2005 10:11:12 -0600
  #   DateTime.civil(2005, 2, 21, 10, 11, 12, Rational(-6, 24)).utc # => Mon, 21 Feb 2005 16:11:12 UTC
  def utc
    utc = new_offset(0)

    Time.utc(
      utc.year, utc.month, utc.day,
      utc.hour, utc.min, utc.sec + utc.sec_fraction
    )
  end
  alias_method :getgm, :utc
  alias_method :getutc, :utc
  alias_method :gmtime, :utc

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
    if other.respond_to? :to_datetime
      super other.to_datetime rescue nil
    else
      super
    end
  end
end
