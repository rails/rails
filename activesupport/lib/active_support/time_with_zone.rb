module ActiveSupport
  # A Time-like class that can represent a time in any time zone. Necessary because standard Ruby Time instances are 
  # limited to UTC and the system's ENV['TZ'] zone
  class TimeWithZone
    include Comparable
    attr_reader :time_zone
  
    def initialize(utc_time, time_zone = nil, local_time = nil)
      @utc = utc_time
      @time = local_time
      @time_zone = time_zone
    end
  
    # Returns a Time instance that represents the time in time_zone
    def time
      @time ||= utc? ? @utc : time_zone.utc_to_local(@utc)
    end

    # Returns a Time instance that represents the time in UTC
    def utc
      @utc ||= utc? ? @time : time_zone.local_to_utc(@time)
    end
    alias_method :comparable_time, :utc
  
    # Returns the underlying TZInfo::TimezonePeriod for the local time
    def period
      @period ||= get_period_for_local
    end

    # Returns the simultaneous time in the specified zone
    def in_time_zone(new_zone)
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
  
    # Changes the time zone to Time.zone without converting the time
    def change_time_zone_to_current
      time.change_time_zone_to_current
    end
  
    # Returns a Time.local() instance of the simultaneous time in your system's ENV['TZ'] zone
    def localtime
      utc.dup.localtime # use #dup because Time#localtime is destructive
    end
  
    def dst?
      utc? ? false : period.dst?
    end
  
    # The TimeZone class has no zone for UTC, so this class uses the absence of a time zone to indicate UTC
    def utc?
      !time_zone
    end
  
    def utc_offset
      utc? ? 0 : period.utc_total_offset
    end
  
    def formatted_offset(colon = true, alternate_utc_string = nil)
      utc? && alternate_utc_string || utc_offset.to_utc_offset_s(colon)
    end
  
    # Time uses #zone to display the time zone abbreviation, so we're duck-typing it
    def zone
      utc? ? 'UTC' : period.abbreviation.to_s
    end
  
    def inspect
      "#{time.strftime('%a, %d %b %Y %H:%M:%S')} #{zone} #{formatted_offset}"
    end

    def xmlschema
      "#{time.strftime("%Y-%m-%dT%H:%M:%S")}#{formatted_offset(true, 'Z')}"
    end
  
    def to_json(options = nil)
      %("#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)}")
    end
  
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
  
    # A TimeProxy acts like a Time, so just return self
    def to_time
      self
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
