require 'active_support/values/time_zone'
require 'active_support/core_ext/object/acts_like'

module ActiveSupport
  # A Time-like class that can represent a time in any time zone. Necessary because standard Ruby Time instances are
  # limited to UTC and the system's <tt>ENV['TZ']</tt> zone.
  #
  # You shouldn't ever need to create a TimeWithZone instance directly via <tt>new</tt> . Instead use methods
  # +local+, +parse+, +at+ and +now+ on TimeZone instances, and +in_time_zone+ on Time and DateTime instances.
  #
  #   Time.zone = 'Eastern Time (US & Canada)'        # => 'Eastern Time (US & Canada)'
  #   Time.zone.local(2007, 2, 10, 15, 30, 45)        # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.parse('2007-02-10 15:30:45')          # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.at(1170361845)                        # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #   Time.zone.now                                   # => Sun, 18 May 2008 13:07:55 EDT -04:00
  #   Time.utc(2007, 2, 10, 20, 30, 45).in_time_zone  # => Sat, 10 Feb 2007 15:30:45 EST -05:00
  #
  # See Time and TimeZone for further documentation of these methods.
  #
  # TimeWithZone instances implement the same API as Ruby Time instances, so that Time and TimeWithZone instances are interchangeable.
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
  #
  class TimeWithZone

    # Report class name as 'Time' to thwart type checking
    def self.name
      'Time'
    end

    include Comparable
    attr_reader :time_zone

    def initialize(utc_time, time_zone, local_time = nil, period = nil)
      @utc, @time_zone, @time = utc_time, time_zone, local_time
      @period = @utc ? period : get_period_and_ensure_valid_local_time
    end

    # Returns a Time or DateTime instance that represents the time in +time_zone+.
    def time
      @time ||= period.to_local(@utc)
    end

    # Returns a Time or DateTime instance that represents the time in UTC.
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

    # Returns a <tt>Time.local()</tt> instance of the simultaneous time in your system's <tt>ENV['TZ']</tt> zone
    def localtime
      utc.respond_to?(:getlocal) ? utc.getlocal : utc.to_time.getlocal
    end
    alias_method :getlocal, :localtime

    def dst?
      period.dst?
    end
    alias_method :isdst, :dst?

    def utc?
      time_zone.name == 'UTC'
    end
    alias_method :gmt?, :utc?

    def utc_offset
      period.utc_total_offset
    end
    alias_method :gmt_offset, :utc_offset
    alias_method :gmtoff, :utc_offset

    def formatted_offset(colon = true, alternate_utc_string = nil)
      utc? && alternate_utc_string || TimeZone.seconds_to_utc_offset(utc_offset, colon)
    end

    # Time uses +zone+ to display the time zone abbreviation, so we're duck-typing it.
    def zone
      period.zone_identifier.to_s
    end

    def inspect
      "#{time.strftime('%a, %d %b %Y %H:%M:%S')} #{zone} #{formatted_offset}"
    end

    def xmlschema(fraction_digits = 0)
      fraction = if fraction_digits > 0
        (".%06i" % time.usec)[0, fraction_digits + 1]
      end

      "#{time.strftime("%Y-%m-%dT%H:%M:%S")}#{fraction}#{formatted_offset(true, 'Z')}"
    end
    alias_method :iso8601, :xmlschema

    # Coerces time to a string for JSON encoding. The default format is ISO 8601. You can get
    # %Y/%m/%d %H:%M:%S +offset style by setting <tt>ActiveSupport::JSON::Encoding.use_standard_json_time_format</tt>
    # to false.
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
    #   Time.utc(2005,2,1,15,15,10).in_time_zone.to_json
    #   # => "2005-02-01T15:15:10Z"
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
    #   Time.utc(2005,2,1,15,15,10).in_time_zone.to_json
    #   # => "2005/02/01 15:15:10 +0000"
    #
    def as_json(options = nil)
      if ActiveSupport::JSON::Encoding.use_standard_json_time_format
        xmlschema
      else
        %(#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
      end
    end

    def encode_with(coder)
      if coder.respond_to?(:represent_object)
        coder.represent_object(nil, utc)
      else
        coder.represent_scalar(nil, utc.strftime("%Y-%m-%d %H:%M:%S.%9NZ"))
      end
    end

    def httpdate
      utc.httpdate
    end

    def rfc2822
      to_s(:rfc822)
    end
    alias_method :rfc822, :rfc2822

    # <tt>:db</tt> format outputs time in UTC; all others output time in local.
    # Uses TimeWithZone's +strftime+, so <tt>%Z</tt> and <tt>%z</tt> work correctly.
    def to_s(format = :default)
      if format == :db
        utc.to_s(format)
      elsif formatter = ::Time::DATE_FORMATS[format]
        formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
      else
        "#{time.strftime("%Y-%m-%d %H:%M:%S")} #{formatted_offset(false, 'UTC')}" # mimicking Ruby 1.9 Time#to_s format
      end
    end
    alias_method :to_formatted_s, :to_s

    # Replaces <tt>%Z</tt> and <tt>%z</tt> directives with +zone+ and +formatted_offset+, respectively, before passing to
    # Time#strftime, so that zone information is correct
    def strftime(format)
      format = format.gsub('%Z', zone)
                     .gsub('%z',   formatted_offset(false))
                     .gsub('%:z',  formatted_offset(true))
                     .gsub('%::z', formatted_offset(true) + ":00")
      time.strftime(format)
    end

    # Use the time in UTC for comparisons.
    def <=>(other)
      utc <=> other
    end

    def between?(min, max)
      utc.between?(min, max)
    end

    def past?
      utc.past?
    end

    def today?
      time.today?
    end

    def future?
      utc.future?
    end

    def eql?(other)
      utc.eql?(other)
    end

    def hash
      utc.hash
    end

    def +(other)
      # If we're adding a Duration of variable length (i.e., years, months, days), move forward from #time,
      # otherwise move forward from #utc, for accuracy when moving across DST boundaries
      if duration_of_variable_length?(other)
        method_missing(:+, other)
      else
        result = utc.acts_like?(:date) ? utc.since(other) : utc + other rescue utc.since(other)
        result.in_time_zone(time_zone)
      end
    end

    def -(other)
      # If we're subtracting a Duration of variable length (i.e., years, months, days), move backwards from #time,
      # otherwise move backwards #utc, for accuracy when moving across DST boundaries
      if other.acts_like?(:time)
        utc.to_f - other.to_f
      elsif duration_of_variable_length?(other)
        method_missing(:-, other)
      else
        result = utc.acts_like?(:date) ? utc.ago(other) : utc - other rescue utc.ago(other)
        result.in_time_zone(time_zone)
      end
    end

    def since(other)
      # If we're adding a Duration of variable length (i.e., years, months, days), move forward from #time,
      # otherwise move forward from #utc, for accuracy when moving across DST boundaries
      if duration_of_variable_length?(other)
        method_missing(:since, other)
      else
        utc.since(other).in_time_zone(time_zone)
      end
    end

    def ago(other)
      since(-other)
    end

    def advance(options)
      # If we're advancing a value of variable length (i.e., years, weeks, months, days), advance from #time,
      # otherwise advance from #utc, for accuracy when moving across DST boundaries
      if options.values_at(:years, :weeks, :months, :days).any?
        method_missing(:advance, options)
      else
        utc.advance(options).in_time_zone(time_zone)
      end
    end

    %w(year mon month day mday wday yday hour min sec to_date).each do |method_name|
      class_eval <<-EOV, __FILE__, __LINE__ + 1
        def #{method_name}    # def month
          time.#{method_name} #   time.month
        end                   # end
      EOV
    end

    def usec
      time.respond_to?(:usec) ? time.usec : 0
    end

    def to_a
      [time.sec, time.min, time.hour, time.day, time.mon, time.year, time.wday, time.yday, dst?, zone]
    end

    def to_f
      utc.to_f
    end

    def to_i
      utc.to_i
    end
    alias_method :tv_sec, :to_i

    # A TimeWithZone acts like a Time, so just return +self+.
    def to_time
      utc
    end

    def to_datetime
      utc.to_datetime.new_offset(Rational(utc_offset, 86_400))
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

    def freeze
      period; utc; time # preload instance variables before freezing
      super
    end

    def marshal_dump
      [utc, time_zone.name, time]
    end

    def marshal_load(variables)
      initialize(variables[0].utc, ::Time.find_zone(variables[1]), variables[2].utc)
    end

    # Ensure proxy class responds to all methods that underlying time instance responds to.
    def respond_to_missing?(sym, include_priv)
      # consistently respond false to acts_like?(:date), regardless of whether #time is a Time or DateTime
      return false if sym.to_sym == :acts_like_date?
      time.respond_to?(sym, include_priv)
    end

    # Send the missing method to +time+ instance, and wrap result in a new TimeWithZone with the existing +time_zone+.
    def method_missing(sym, *args, &block)
      wrap_with_time_zone time.__send__(sym, *args, &block)
    end

    private
      def get_period_and_ensure_valid_local_time
        # we don't want a Time.local instance enforcing its own DST rules as well,
        # so transfer time values to a utc constructor if necessary
        @time = transfer_time_values_to_utc_constructor(@time) unless @time.utc?
        begin
          @time_zone.period_for_local(@time)
        rescue ::TZInfo::PeriodNotFound
          # time is in the "spring forward" hour gap, so we're moving the time forward one hour and trying again
          @time += 1.hour
          retry
        end
      end

      def transfer_time_values_to_utc_constructor(time)
        ::Time.utc_time(time.year, time.month, time.day, time.hour, time.min, time.sec, time.respond_to?(:nsec) ? Rational(time.nsec, 1000) : 0)
      end

      def duration_of_variable_length?(obj)
        ActiveSupport::Duration === obj && obj.parts.any? {|p| [:years, :months, :days].include?(p[0]) }
      end

      def wrap_with_time_zone(time)
        if time.acts_like?(:time)
          self.class.new(nil, time_zone, time)
        elsif time.is_a?(Range)
          wrap_with_time_zone(time.begin)..wrap_with_time_zone(time.end)
        else
          time
        end
      end
  end
end
