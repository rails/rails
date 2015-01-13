require 'tzinfo'
require 'thread_safe'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/values/time_zone'

module ActiveSupport
  # The TimeZone class serves as a wrapper around TZInfo::Timezone instances.
  # It allows us to do the following:
  #
  # * Limit the set of zones provided by TZInfo to a meaningful subset of 146
  #   zones.
  # * Retrieve and display zones with a friendlier name
  #   (e.g., "Eastern Time (US & Canada)" instead of "America/New_York").
  # * Lazily load TZInfo::Timezone instances only when they're needed.
  # * Create ActiveSupport::TimeWithZone instances via TimeZone's +local+,
  #   +parse+, +at+ and +now+ methods.
  #
  # If you set <tt>config.time_zone</tt> in the Rails Application, you can
  # access this TimeZone object via <tt>Time.zone</tt>:
  #
  #   # application.rb:
  #   class Application < Rails::Application
  #     config.time_zone = 'Eastern Time (US & Canada)'
  #   end
  #
  #   Time.zone      # => #<TimeZone:0x514834...>
  #   Time.zone.name # => "Eastern Time (US & Canada)"
  #   Time.zone.now  # => Sun, 18 May 2008 14:30:44 EDT -04:00
  #
  # The version of TZInfo bundled with Active Support only includes the
  # definitions necessary to support the zones defined by the TimeZone class.
  # If you need to use zones that aren't defined by TimeZone, you'll need to
  # install the TZInfo gem (if a recent version of the gem is installed locally,
  # this will be used instead of the bundled version.)
  class TimeZone
    UTC_OFFSET_WITH_COLON = '%s%02d:%02d'
    UTC_OFFSET_WITHOUT_COLON = UTC_OFFSET_WITH_COLON.tr(':', '')

    @lazy_zones_map = ThreadSafe::Cache.new

    class << self
      # Assumes self represents an offset from UTC in seconds (as returned from
      # Time#utc_offset) and turns this into an +HH:MM formatted string.
      #
      #   TimeZone.seconds_to_utc_offset(-21_600) # => "-06:00"
      def seconds_to_utc_offset(seconds, colon = true)
        format = colon ? UTC_OFFSET_WITH_COLON : UTC_OFFSET_WITHOUT_COLON
        sign = (seconds < 0 ? '-' : '+')
        hours = seconds.abs / 3600
        minutes = (seconds.abs % 3600) / 60
        format % [sign, hours, minutes]
      end

      def find_tzinfo(name)
        TZInfo::Timezone.new(MAPPING[name] || name)
      end

      alias_method :create, :new

      # Returns a TimeZone instance with the given name, or +nil+ if no
      # such TimeZone instance exists. (This exists to support the use of
      # this class with the +composed_of+ macro.)
      def new(name)
        self[name]
      end

      # Returns an array of all TimeZone objects. There are multiple
      # TimeZone objects per time zone, in many cases, to make it easier
      # for users to find their own time zone.
      def all
        @zones ||= zones_map.values.sort
      end

      def zones_map
        @zones_map ||= begin
          MAPPING.each_key {|place| self[place]} # load all the zones
          @lazy_zones_map
        end
      end

      # Locate a specific time zone object. If the argument is a string, it
      # is interpreted to mean the name of the timezone to locate. If it is a
      # numeric value it is either the hour offset, or the second offset, of the
      # timezone to find. (The first one with that offset will be returned.)
      # Returns +nil+ if no such time zone is known to the system.
      def [](arg)
        case arg
          when String
          begin
            @lazy_zones_map[arg] ||= create(arg)
          rescue TZInfo::InvalidTimezoneIdentifier
            nil
          end
          when Numeric, ActiveSupport::Duration
            arg *= 3600 if arg.abs <= 13
            all.find { |z| z.utc_offset == arg.to_i }
          else
            raise ArgumentError, "invalid argument to TimeZone[]: #{arg.inspect}"
        end
      end

      # A convenience method for returning a collection of TimeZone objects
      # for time zones in the USA.
      def us_zones
        @us_zones ||= all.find_all { |z| z.name =~ /US|Arizona|Indiana|Hawaii|Alaska/ }
      end
    end

    include Comparable
    attr_reader :name
    attr_reader :tzinfo

    # Create a new TimeZone object with the given name and offset. The
    # offset is the number of seconds that this time zone is offset from UTC
    # (GMT). Seconds were chosen as the offset unit because that is the unit
    # that Ruby uses to represent time zone offsets (see Time#utc_offset).
    def initialize(name, utc_offset = nil, tzinfo = nil)
      @name = name
      @utc_offset = utc_offset
      @tzinfo = tzinfo || TimeZone.find_tzinfo(name)
      @current_period = nil
    end

    # Returns the offset of this time zone from UTC in seconds.
    def utc_offset
      if @utc_offset
        @utc_offset
      else
        @current_period ||= tzinfo.current_period if tzinfo
        @current_period.utc_offset if @current_period
      end
    end

    # Returns the offset of this time zone as a formatted string, of the
    # format "+HH:MM".
    def formatted_offset(colon=true, alternate_utc_string = nil)
      utc_offset == 0 && alternate_utc_string || self.class.seconds_to_utc_offset(utc_offset, colon)
    end

    # Compare this time zone to the parameter. The two are compared first on
    # their offsets, and then by name.
    def <=>(zone)
      return unless zone.respond_to? :utc_offset
      result = (utc_offset <=> zone.utc_offset)
      result = (name <=> zone.name) if result == 0
      result
    end

    # Compare #name and TZInfo identifier to a supplied regexp, returning +true+
    # if a match is found.
    def =~(re)
      re === name || re === MAPPING[name]
    end

    # Returns a textual representation of this time zone.
    def to_s
      "(GMT#{formatted_offset}) #{name}"
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone
    # of +self+ from given values.
    #
    #   Time.zone = 'Hawaii'                    # => "Hawaii"
    #   Time.zone.local(2007, 2, 1, 15, 30, 45) # => Thu, 01 Feb 2007 15:30:45 HST -10:00
    def local(*args)
      time = Time.utc(*args)
      ActiveSupport::TimeWithZone.new(nil, self, time)
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone
    # of +self+ from number of seconds since the Unix epoch.
    #
    #   Time.zone = 'Hawaii'        # => "Hawaii"
    #   Time.utc(2000).to_f         # => 946684800.0
    #   Time.zone.at(946684800.0)   # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    def at(secs)
      Time.at(secs).utc.in_time_zone(self)
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone
    # of +self+ from parsed string.
    #
    #   Time.zone = 'Hawaii'                   # => "Hawaii"
    #   Time.zone.parse('1999-12-31 14:00:00') # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    #
    # If upper components are missing from the string, they are supplied from
    # TimeZone#now:
    #
    #   Time.zone.now               # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    #   Time.zone.parse('22:30:00') # => Fri, 31 Dec 1999 22:30:00 HST -10:00
    #
    # However, if the date component is not provided, but any other upper
    # components are supplied, then the day of the month defaults to 1:
    #
    #   Time.zone.parse('Mar 2000') # => Wed, 01 Mar 2000 00:00:00 HST -10:00
    def parse(str, now=now())
      parts = Date._parse(str, false)
      return if parts.empty?

      time = Time.new(
        parts.fetch(:year, now.year),
        parts.fetch(:mon, now.month),
        parts.fetch(:mday, parts[:year] || parts[:mon] ? 1 : now.day),
        parts.fetch(:hour, 0),
        parts.fetch(:min, 0),
        parts.fetch(:sec, 0) + parts.fetch(:sec_fraction, 0),
        parts.fetch(:offset, 0)
      )

      if parts[:offset]
        TimeWithZone.new(time.utc, self)
      else
        TimeWithZone.new(nil, self, time)
      end
    end

    # Returns an ActiveSupport::TimeWithZone instance representing the current
    # time in the time zone represented by +self+.
    #
    #   Time.zone = 'Hawaii'  # => "Hawaii"
    #   Time.zone.now         # => Wed, 23 Jan 2008 20:24:27 HST -10:00
    def now
      time_now.utc.in_time_zone(self)
    end

    # Return the current date in this time zone.
    def today
      tzinfo.now.to_date
    end

    # Returns the next date in this time zone.
    def tomorrow
      today + 1
    end

    # Returns the previous date in this time zone.
    def yesterday
      today - 1
    end

    # Adjust the given time to the simultaneous time in the time zone
    # represented by +self+. Returns a Time.utc() instance -- if you want an
    # ActiveSupport::TimeWithZone instance, use Time#in_time_zone() instead.
    def utc_to_local(time)
      tzinfo.utc_to_local(time)
    end

    # Adjust the given time to the simultaneous time in UTC. Returns a
    # Time.utc() instance.
    def local_to_utc(time, dst=true)
      tzinfo.local_to_utc(time, dst)
    end

    # Available so that TimeZone instances respond like TZInfo::Timezone
    # instances.
    def period_for_utc(time)
      tzinfo.period_for_utc(time)
    end

    # Available so that TimeZone instances respond like TZInfo::Timezone
    # instances.
    def period_for_local(time, dst=true)
      tzinfo.period_for_local(time, dst)
    end

    def periods_for_local(time) #:nodoc:
      tzinfo.periods_for_local(time)
    end

    private
      def time_now
        Time.now
      end
  end
end
