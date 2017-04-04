require "active_support/duration"
require "active_support/values/time_zone"
require "active_support/core_ext/object/acts_like"
require "active_support/core_ext/date_and_time/compatibility"

module ActiveSupport
  # A Time-like class that can represent a time in any time zone. Necessary
  # because standard Ruby Time instances are limited to UTC and the
  # system's <tt>ENV['TZ']</tt> zone.
  #
  # You shouldn't ever need to create a TimeWithZone instance directly via +new+.
  # Instead use methods +local+, +parse+, +at+ and +now+ on TimeZone instances,
  # and +in_time_zone+ on Time and DateTime instances.
  #
  #   Time.zone = 'Eastern Time (US & Canada)'        # => 'Eastern Time (US & Canada)'
  #   Time.zone.local(2007, 2, 10, 15, 30, 45)        # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.parse('2007-02-10 15:30:45')          # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.at(1171139445)                        # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.now                                   # => Sun, 18 May 2008 13:07:55 EDT -04:00
  #   Time.utc(2007, 2, 10, 20, 30, 45).in_time_zone  # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #
  # See Time and TimeZone for further documentation of these methods.
  #
  # TimeWithZone instances implement the same API as Ruby Time instances, so
  # that Time and TimeWithZone instances are interchangeable.
  #
  #   t = Time.zone.now                     # => Sun, 18 May 2008 13:27:25 EDT -04:00
  #   t.hour                                # => 13
  #   t.dst?                                # => true
  #   t.utc_offset                          # => -14400
  #   t.zone                                # => "EDT"
  #   t.to_s(:rfc822)                       # => "Sun, 18 May 2008 13:27:25 -0400"
  #   t + 1.day                             # => Mon, 19 May 2008 13:27:25 EDT -04:00
  #   t.beginning_of_year                   # => Tue, 01 Jan 2008 00:00:00 EST -05:00
  #   t > Time.utc(1999)                    # => true
  #   t.is_a?(Time)                         # => true
  #   t.is_a?(ActiveSupport::TimeWithZone)  # => true
  class TimeWithZone
    # Report class name as 'Time' to thwart type checking.
    def self.name
      "Time"
    end

    PRECISIONS = Hash.new { |h, n| h[n] = "%FT%T.%#{n}N".freeze }
    PRECISIONS[0] = "%FT%T".freeze

    include Comparable, DateAndTime::Compatibility
    attr_reader :time_zone

    def initialize(utc_time, time_zone, local_time = nil, period = nil)
      @utc = utc_time ? transfer_time_values_to_utc_constructor(utc_time) : nil
      @time_zone, @time = time_zone, local_time
      @period = @utc ? period : get_period_and_ensure_valid_local_time(period)
    end

    # Returns a <tt>Time</tt> instance that represents the time in +time_zone+.
    def time
      @time ||= period.to_local(@utc)
    end

    # Returns a <tt>Time</tt> instance of the simultaneous time in the UTC timezone.
    def utc
      @utc ||= period.to_utc(@time)
    end
    alias_method :comparable_time, :utc
    alias_method :getgm, :utc
    alias_method :getutc, :utc
    alias_method :gmtime, :utc

    # Returns the underlying TZInfo::TimezonePeriod.
    def period
      @period ||= time_zone.period_for_utc(@utc)
    end

    # Returns the simultaneous time in <tt>Time.zone</tt>, or the specified zone.
    def in_time_zone(new_zone = ::Time.zone)
      return self if time_zone == new_zone
      utc.in_time_zone(new_zone)
    end

    # Returns a <tt>Time</tt> instance of the simultaneous time in the system timezone.
    def localtime(utc_offset = nil)
      utc.getlocal(utc_offset)
    end
    alias_method :getlocal, :localtime

    # Returns true if the current time is within Daylight Savings Time for the
    # specified time zone.
    #
    #   Time.zone = 'Eastern Time (US & Canada)'    # => 'Eastern Time (US & Canada)'
    #   Time.zone.parse("2012-5-30").dst?           # => true
    #   Time.zone.parse("2012-11-30").dst?          # => false
    def dst?
      period.dst?
    end
    alias_method :isdst, :dst?

    # Returns true if the current time zone is set to UTC.
    #
    #   Time.zone = 'UTC'                           # => 'UTC'
    #   Time.zone.now.utc?                          # => true
    #   Time.zone = 'Eastern Time (US & Canada)'    # => 'Eastern Time (US & Canada)'
    #   Time.zone.now.utc?                          # => false
    def utc?
      period.offset.abbreviation == :UTC || period.offset.abbreviation == :UCT
    end
    alias_method :gmt?, :utc?

    # Returns the offset from current time to UTC time in seconds.
    def utc_offset
      period.utc_total_offset
    end
    alias_method :gmt_offset, :utc_offset
    alias_method :gmtoff, :utc_offset

    # Returns a formatted string of the offset from UTC, or an alternative
    # string if the time zone is already UTC.
    #
    #   Time.zone = 'Eastern Time (US & Canada)'   # => "Eastern Time (US & Canada)"
    #   Time.zone.now.formatted_offset(true)       # => "-05:00"
    #   Time.zone.now.formatted_offset(false)      # => "-0500"
    #   Time.zone = 'UTC'                          # => "UTC"
    #   Time.zone.now.formatted_offset(true, "0")  # => "0"
    def formatted_offset(colon = true, alternate_utc_string = nil)
      utc? && alternate_utc_string || TimeZone.seconds_to_utc_offset(utc_offset, colon)
    end

    # Returns the time zone abbreviation.
    #
    #   Time.zone = 'Eastern Time (US & Canada)'   # => "Eastern Time (US & Canada)"
    #   Time.zone.now.zone # => "EST"
    def zone
      period.zone_identifier.to_s
    end

    # Returns a string of the object's date, time, zone, and offset from UTC.
    #
    #   Time.zone.now.inspect # => "Thu, 04 Dec 2014 11:00:25 EST -05:00"
    def inspect
      "#{time.strftime('%a, %d %b %Y %H:%M:%S')} #{zone} #{formatted_offset}"
    end

    # Returns a string of the object's date and time in the ISO 8601 standard
    # format.
    #
    #   Time.zone.now.xmlschema  # => "2014-12-04T11:02:37-05:00"
    def xmlschema(fraction_digits = 0)
      "#{time.strftime(PRECISIONS[fraction_digits.to_i])}#{formatted_offset(true, 'Z'.freeze)}"
    end
    alias_method :iso8601, :xmlschema
    alias_method :rfc3339, :xmlschema

    # Coerces time to a string for JSON encoding. The default format is ISO 8601.
    # You can get %Y/%m/%d %H:%M:%S +offset style by setting
    # <tt>ActiveSupport::JSON::Encoding.use_standard_json_time_format</tt>
    # to +false+.
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
    #   Time.utc(2005,2,1,15,15,10).in_time_zone("Hawaii").to_json
    #   # => "2005-02-01T05:15:10.000-10:00"
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
    #   Time.utc(2005,2,1,15,15,10).in_time_zone("Hawaii").to_json
    #   # => "2005/02/01 05:15:10 -1000"
    def as_json(options = nil)
      if ActiveSupport::JSON::Encoding.use_standard_json_time_format
        xmlschema(ActiveSupport::JSON::Encoding.time_precision)
      else
        %(#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
      end
    end

    def init_with(coder) #:nodoc:
      initialize(coder["utc"], coder["zone"], coder["time"])
    end

    def encode_with(coder) #:nodoc:
      coder.tag = "!ruby/object:ActiveSupport::TimeWithZone"
      coder.map = { "utc" => utc, "zone" => time_zone, "time" => time }
    end

    # Returns a string of the object's date and time in the format used by
    # HTTP requests.
    #
    #   Time.zone.now.httpdate  # => "Tue, 01 Jan 2013 04:39:43 GMT"
    def httpdate
      utc.httpdate
    end

    # Returns a string of the object's date and time in the RFC 2822 standard
    # format.
    #
    #   Time.zone.now.rfc2822  # => "Tue, 01 Jan 2013 04:51:39 +0000"
    def rfc2822
      to_s(:rfc822)
    end
    alias_method :rfc822, :rfc2822

    # Returns a string of the object's date and time.
    # Accepts an optional <tt>format</tt>:
    # * <tt>:default</tt> - default value, mimics Ruby Time#to_s format.
    # * <tt>:db</tt> - format outputs time in UTC :db time. See Time#to_formatted_s(:db).
    # * Any key in <tt>Time::DATE_FORMATS</tt> can be used. See active_support/core_ext/time/conversions.rb.
    def to_s(format = :default)
      if format == :db
        utc.to_s(format)
      elsif formatter = ::Time::DATE_FORMATS[format]
        formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
      else
        "#{time.strftime("%Y-%m-%d %H:%M:%S")} #{formatted_offset(false, 'UTC')}" # mimicking Ruby Time#to_s format
      end
    end
    alias_method :to_formatted_s, :to_s

    # Replaces <tt>%Z</tt> directive with +zone before passing to Time#strftime,
    # so that zone information is correct.
    def strftime(format)
      format = format.gsub(/((?:\A|[^%])(?:%%)*)%Z/, "\\1#{zone}")
      getlocal(utc_offset).strftime(format)
    end

    # Use the time in UTC for comparisons.
    def <=>(other)
      utc <=> other
    end

    # Returns true if the current object's time is within the specified
    # +min+ and +max+ time.
    def between?(min, max)
      utc.between?(min, max)
    end

    # Returns true if the current object's time is in the past.
    def past?
      utc.past?
    end

    # Returns true if the current object's time falls within
    # the current day.
    def today?
      time.today?
    end

    # Returns true if the current object's time is in the future.
    def future?
      utc.future?
    end

    # Returns +true+ if +other+ is equal to current object.
    def eql?(other)
      other.eql?(utc)
    end

    def hash
      utc.hash
    end

    # Adds an interval of time to the current object's time and returns that
    # value as a new TimeWithZone object.
    #
    #   Time.zone = 'Eastern Time (US & Canada)' # => 'Eastern Time (US & Canada)'
    #   now = Time.zone.now # => Sun, 02 Nov 2014 01:26:28 EDT -04:00
    #   now + 1000          # => Sun, 02 Nov 2014 01:43:08 EDT -04:00
    #
    # If we're adding a Duration of variable length (i.e., years, months, days),
    # move forward from #time, otherwise move forward from #utc, for accuracy
    # when moving across DST boundaries.
    #
    # For instance, a time + 24.hours will advance exactly 24 hours, while a
    # time + 1.day will advance 23-25 hours, depending on the day.
    #
    #   now + 24.hours      # => Mon, 03 Nov 2014 00:26:28 EST -05:00
    #   now + 1.day         # => Mon, 03 Nov 2014 01:26:28 EST -05:00
    def +(other)
      if duration_of_variable_length?(other)
        method_missing(:+, other)
      else
        result = utc.acts_like?(:date) ? utc.since(other) : utc + other rescue utc.since(other)
        result.in_time_zone(time_zone)
      end
    end
    alias_method :since, :+
    alias_method :in, :+

    # Returns a new TimeWithZone object that represents the difference between
    # the current object's time and the +other+ time.
    #
    #   Time.zone = 'Eastern Time (US & Canada)' # => 'Eastern Time (US & Canada)'
    #   now = Time.zone.now # => Mon, 03 Nov 2014 00:26:28 EST -05:00
    #   now - 1000          # => Mon, 03 Nov 2014 00:09:48 EST -05:00
    #
    # If subtracting a Duration of variable length (i.e., years, months, days),
    # move backward from #time, otherwise move backward from #utc, for accuracy
    # when moving across DST boundaries.
    #
    # For instance, a time - 24.hours will go subtract exactly 24 hours, while a
    # time - 1.day will subtract 23-25 hours, depending on the day.
    #
    #   now - 24.hours      # => Sun, 02 Nov 2014 01:26:28 EDT -04:00
    #   now - 1.day         # => Sun, 02 Nov 2014 00:26:28 EDT -04:00
    def -(other)
      if other.acts_like?(:time)
        to_time - other.to_time
      elsif duration_of_variable_length?(other)
        method_missing(:-, other)
      else
        result = utc.acts_like?(:date) ? utc.ago(other) : utc - other rescue utc.ago(other)
        result.in_time_zone(time_zone)
      end
    end

    # Subtracts an interval of time from the current object's time and returns
    # the result as a new TimeWithZone object.
    #
    #   Time.zone = 'Eastern Time (US & Canada)' # => 'Eastern Time (US & Canada)'
    #   now = Time.zone.now # => Mon, 03 Nov 2014 00:26:28 EST -05:00
    #   now.ago(1000)       # => Mon, 03 Nov 2014 00:09:48 EST -05:00
    #
    # If we're subtracting a Duration of variable length (i.e., years, months,
    # days), move backward from #time, otherwise move backward from #utc, for
    # accuracy when moving across DST boundaries.
    #
    # For instance, <tt>time.ago(24.hours)</tt> will move back exactly 24 hours,
    # while <tt>time.ago(1.day)</tt> will move back 23-25 hours, depending on
    # the day.
    #
    #   now.ago(24.hours)   # => Sun, 02 Nov 2014 01:26:28 EDT -04:00
    #   now.ago(1.day)      # => Sun, 02 Nov 2014 00:26:28 EDT -04:00
    def ago(other)
      since(-other)
    end

    # Uses Date to provide precise Time calculations for years, months, and days
    # according to the proleptic Gregorian calendar. The result is returned as a
    # new TimeWithZone object.
    #
    # The +options+ parameter takes a hash with any of these keys:
    # <tt>:years</tt>, <tt>:months</tt>, <tt>:weeks</tt>, <tt>:days</tt>,
    # <tt>:hours</tt>, <tt>:minutes</tt>, <tt>:seconds</tt>.
    #
    # If advancing by a value of variable length (i.e., years, weeks, months,
    # days), move forward from #time, otherwise move forward from #utc, for
    # accuracy when moving across DST boundaries.
    #
    #   Time.zone = 'Eastern Time (US & Canada)' # => 'Eastern Time (US & Canada)'
    #   now = Time.zone.now # => Sun, 02 Nov 2014 01:26:28 EDT -04:00
    #   now.advance(seconds: 1) # => Sun, 02 Nov 2014 01:26:29 EDT -04:00
    #   now.advance(minutes: 1) # => Sun, 02 Nov 2014 01:27:28 EDT -04:00
    #   now.advance(hours: 1)   # => Sun, 02 Nov 2014 01:26:28 EST -05:00
    #   now.advance(days: 1)    # => Mon, 03 Nov 2014 01:26:28 EST -05:00
    #   now.advance(weeks: 1)   # => Sun, 09 Nov 2014 01:26:28 EST -05:00
    #   now.advance(months: 1)  # => Tue, 02 Dec 2014 01:26:28 EST -05:00
    #   now.advance(years: 1)   # => Mon, 02 Nov 2015 01:26:28 EST -05:00
    def advance(options)
      # If we're advancing a value of variable length (i.e., years, weeks, months, days), advance from #time,
      # otherwise advance from #utc, for accuracy when moving across DST boundaries
      if options.values_at(:years, :weeks, :months, :days).any?
        method_missing(:advance, options)
      else
        utc.advance(options).in_time_zone(time_zone)
      end
    end

    %w(year mon month day mday wday yday hour min sec usec nsec to_date).each do |method_name|
      class_eval <<-EOV, __FILE__, __LINE__ + 1
        def #{method_name}    # def month
          time.#{method_name} #   time.month
        end                   # end
      EOV
    end

    # Returns Array of parts of Time in sequence of
    # [seconds, minutes, hours, day, month, year, weekday, yearday, dst?, zone].
    #
    #   now = Time.zone.now     # => Tue, 18 Aug 2015 02:29:27 UTC +00:00
    #   now.to_a                # => [27, 29, 2, 18, 8, 2015, 2, 230, false, "UTC"]
    def to_a
      [time.sec, time.min, time.hour, time.day, time.mon, time.year, time.wday, time.yday, dst?, zone]
    end

    # Returns the object's date and time as a floating point number of seconds
    # since the Epoch (January 1, 1970 00:00 UTC).
    #
    #   Time.zone.now.to_f # => 1417709320.285418
    def to_f
      utc.to_f
    end

    # Returns the object's date and time as an integer number of seconds
    # since the Epoch (January 1, 1970 00:00 UTC).
    #
    #   Time.zone.now.to_i # => 1417709320
    def to_i
      utc.to_i
    end
    alias_method :tv_sec, :to_i

    # Returns the object's date and time as a rational number of seconds
    # since the Epoch (January 1, 1970 00:00 UTC).
    #
    #   Time.zone.now.to_r # => (708854548642709/500000)
    def to_r
      utc.to_r
    end

    # Returns an instance of DateTime with the timezone's UTC offset
    #
    #   Time.zone.now.to_datetime                         # => Tue, 18 Aug 2015 02:32:20 +0000
    #   Time.current.in_time_zone('Hawaii').to_datetime   # => Mon, 17 Aug 2015 16:32:20 -1000
    def to_datetime
      @to_datetime ||= utc.to_datetime.new_offset(Rational(utc_offset, 86_400))
    end

    # Returns an instance of +Time+, either with the same UTC offset
    # as +self+ or in the local system timezone depending on the setting
    # of +ActiveSupport.to_time_preserves_timezone+.
    def to_time
      if preserve_timezone
        @to_time_with_instance_offset ||= getlocal(utc_offset)
      else
        @to_time_with_system_offset ||= getlocal
      end
    end

    # So that +self+ <tt>acts_like?(:time)</tt>.
    def acts_like_time?
      true
    end

    # Say we're a Time to thwart type checking.
    def is_a?(klass)
      klass == ::Time || super
    end
    alias_method :kind_of?, :is_a?

    # An instance of ActiveSupport::TimeWithZone is never blank
    def blank?
      false
    end

    def freeze
      # preload instance variables before freezing
      period; utc; time; to_datetime; to_time
      super
    end

    def marshal_dump
      [utc, time_zone.name, time]
    end

    def marshal_load(variables)
      initialize(variables[0].utc, ::Time.find_zone(variables[1]), variables[2].utc)
    end

    # respond_to_missing? is not called in some cases, such as when type conversion is
    # performed with Kernel#String
    def respond_to?(sym, include_priv = false)
      # ensure that we're not going to throw and rescue from NoMethodError in method_missing which is slow
      return false if sym.to_sym == :to_str
      super
    end

    # Ensure proxy class responds to all methods that underlying time instance
    # responds to.
    def respond_to_missing?(sym, include_priv)
      return false if sym.to_sym == :acts_like_date?
      time.respond_to?(sym, include_priv)
    end

    # Send the missing method to +time+ instance, and wrap result in a new
    # TimeWithZone with the existing +time_zone+.
    def method_missing(sym, *args, &block)
      wrap_with_time_zone time.__send__(sym, *args, &block)
    rescue NoMethodError => e
      raise e, e.message.sub(time.inspect, inspect), e.backtrace
    end

    private
      def get_period_and_ensure_valid_local_time(period)
        # we don't want a Time.local instance enforcing its own DST rules as well,
        # so transfer time values to a utc constructor if necessary
        @time = transfer_time_values_to_utc_constructor(@time) unless @time.utc?
        begin
          period || @time_zone.period_for_local(@time)
        rescue ::TZInfo::PeriodNotFound
          # time is in the "spring forward" hour gap, so we're moving the time forward one hour and trying again
          @time += 1.hour
          retry
        end
      end

      def transfer_time_values_to_utc_constructor(time)
        # avoid creating another Time object if possible
        return time if time.instance_of?(::Time) && time.utc?
        ::Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec + time.subsec)
      end

      def duration_of_variable_length?(obj)
        ActiveSupport::Duration === obj && obj.parts.any? { |p| [:years, :months, :weeks, :days].include?(p[0]) }
      end

      def wrap_with_time_zone(time)
        if time.acts_like?(:time)
          periods = time_zone.periods_for_local(time)
          self.class.new(nil, time_zone, time, periods.include?(period) ? period : nil)
        elsif time.is_a?(Range)
          wrap_with_time_zone(time.begin)..wrap_with_time_zone(time.end)
        else
          time
        end
      end
  end
end
