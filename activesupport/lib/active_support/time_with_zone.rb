module ActiveSupport
  # A Time-like class that can represent a time in any time zone. Necessary because standard Ruby Time instances are 
  # limited to UTC and the system's ENV['TZ'] zone
  class TimeWithZone
    include Comparable
    attr_reader :time_zone
  
    def initialize(utc_time, time_zone, local_time = nil)
      @utc = utc_time
      @time = local_time
      @time_zone = time_zone
    end
  
    # Returns a Time instance that represents the time in time_zone
    def time
      @time ||= time_zone.utc_to_local(@utc)
    end

    # Returns a Time instance that represents the time in UTC
    def utc
      @utc ||= time_zone.local_to_utc(@time)
    end
    alias_method :comparable_time, :utc
    alias_method :getgm, :utc
    alias_method :getutc, :utc
    alias_method :gmtime, :utc
  
    # Returns the underlying TZInfo::TimezonePeriod for the local time
    def period
      @period ||= get_period_for_local
    end

    # Returns the simultaneous time in the specified zone
    def in_time_zone(new_zone)
      return self if time_zone == new_zone
      utc.in_time_zone(new_zone)
    end
  
    # Returns the simultaneous time in Time.zone
    def in_current_time_zone
      utc.in_current_time_zone
    end
  
    # Changes the time zone without converting the time
    def change_time_zone(new_zone)
      time.change_time_zone(new_zone)
    end
  
    # Returns a Time.local() instance of the simultaneous time in your system's ENV['TZ'] zone
    def localtime
      utc.getlocal
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
      utc? && alternate_utc_string || utc_offset.to_utc_offset_s(colon)
    end
  
    # Time uses #zone to display the time zone abbreviation, so we're duck-typing it
    def zone
      period.abbreviation.to_s
    end
  
    def inspect
      "#{time.strftime('%a, %d %b %Y %H:%M:%S')} #{zone} #{formatted_offset}"
    end

    def xmlschema
      "#{time.strftime("%Y-%m-%dT%H:%M:%S")}#{formatted_offset(true, 'Z')}"
    end
    alias_method :iso8601, :xmlschema
  
    def to_json(options = nil)
      %("#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)}")
    end
    
    def to_yaml(options = {})
      time.to_yaml(options).gsub('Z', formatted_offset(true, 'Z'))
    end
    
    def httpdate
      utc.httpdate
    end
  
    def rfc2822
      to_s(:rfc822)
    end
    alias_method :rfc822, :rfc2822
  
    # :db format outputs time in UTC; all others output time in local. Uses TimeWithZone's strftime, so %Z and %z work correctly
    def to_s(format = :default) 
      return utc.to_s(format) if format == :db
      if formatter = ::Time::DATE_FORMATS[format]
        formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
      else
        "#{time.strftime("%Y-%m-%d %H:%M:%S")} #{formatted_offset(false, 'UTC')}" # mimicking Ruby 1.9 Time#to_s format
      end
    end
    
    # Replaces %Z and %z directives with #zone and #formatted_offset, respectively, before passing to 
    # Time#strftime, so that zone information is correct
    def strftime(format)
      format = format.gsub('%Z', zone).gsub('%z', formatted_offset(false))
      time.strftime(format)
    end
  
    # Use the time in UTC for comparisons
    def <=>(other)
      utc <=> other
    end
    
    def between?(min, max)
      utc.between?(min, max)
    end
    
    def eql?(other)
      utc == other
    end
    
    # If wrapped #time is a DateTime, use DateTime#since instead of #+
    # Otherwise, just pass on to #method_missing
    def +(other)
      time.acts_like?(:date) ? method_missing(:since, other) : method_missing(:+, other)
    end
    
    # If a time-like object is passed in, compare it with #utc
    # Else if wrapped #time is a DateTime, use DateTime#ago instead of #-
    # Otherwise, just pass on to method missing
    def -(other)
      if other.acts_like?(:time)
        utc - other
      else
        time.acts_like?(:date) ? method_missing(:ago, other) : method_missing(:-, other)
      end
    end
    
    def to_a
      time.to_a[0, 8].push(dst?, zone)
    end
    
    def to_f
      utc.to_f
    end    
    
    def to_i
      utc.to_i
    end
    alias_method :hash, :to_i
    alias_method :tv_sec, :to_i
  
    # A TimeWithZone acts like a Time, so just return self
    def to_time
      self
    end
    
    def to_datetime
      utc.to_datetime.new_offset(Rational(utc_offset, 86_400))
    end
    
    # so that self acts_like?(:time)
    def acts_like_time?
      true
    end
  
    # Say we're a Time to thwart type checking
    def is_a?(klass)
      klass == ::Time || super
    end
    alias_method :kind_of?, :is_a?
  
    # Neuter freeze because freezing can cause problems with lazy loading of attributes
    def freeze
      self
    end
  
    # Ensure proxy class responds to all methods that underlying time instance responds to
    def respond_to?(sym)
      # consistently respond false to acts_like?(:date), regardless of whether #time is a Time or DateTime
      return false if sym.to_s == 'acts_like_date?'
      super || time.respond_to?(sym)
    end
  
    # Send the missing method to time instance, and wrap result in a new TimeWithZone with the existing time_zone
    def method_missing(sym, *args, &block)
      result = time.__send__(sym, *args, &block)
      result = result.change_time_zone(time_zone) if result.acts_like?(:time)
      result
    end
  
    private
      def get_period_for_local
        t = time
        begin
          time_zone.period_for_local(t, true)
        rescue ::TZInfo::PeriodNotFound # failover logic from TzTime
          t -= 1.hour
          retry
        end
      end
  end
end
