require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'

# The TimeZone class serves as a wrapper around TZInfo::Timezone instances. It allows us to do the following:
#
# * Limit the set of zones provided by TZInfo to a meaningful subset of 142 zones.
# * Retrieve and display zones with a friendlier name (e.g., "Eastern Time (US & Canada)" instead of "America/New_York").
# * Lazily load TZInfo::Timezone instances only when they're needed.
# * Create ActiveSupport::TimeWithZone instances via TimeZone's +local+, +parse+, +at+ and +now+ methods.
#
# If you set <tt>config.time_zone</tt> in the Rails Application, you can access this TimeZone object via <tt>Time.zone</tt>:
#
#   # application.rb:
#   class Application < Rails::Application
#     config.time_zone = "Eastern Time (US & Canada)"
#   end
#
#   Time.zone       # => #<TimeZone:0x514834...>
#   Time.zone.name  # => "Eastern Time (US & Canada)"
#   Time.zone.now   # => Sun, 18 May 2008 14:30:44 EDT -04:00
#
# The version of TZInfo bundled with Active Support only includes the definitions necessary to support the zones
# defined by the TimeZone class. If you need to use zones that aren't defined by TimeZone, you'll need to install the TZInfo gem
# (if a recent version of the gem is installed locally, this will be used instead of the bundled version.)
module ActiveSupport
  class TimeZone
    # Keys are Rails TimeZone names, values are TZInfo identifiers
    MAPPING = {
      "International Date Line West" => "Pacific/Midway",
      "Midway Island"                => "Pacific/Midway",
      "Samoa"                        => "Pacific/Pago_Pago",
      "Hawaii"                       => "Pacific/Honolulu",
      "Alaska"                       => "America/Juneau",
      "Pacific Time (US & Canada)"   => "America/Los_Angeles",
      "Tijuana"                      => "America/Tijuana",
      "Mountain Time (US & Canada)"  => "America/Denver",
      "Arizona"                      => "America/Phoenix",
      "Chihuahua"                    => "America/Chihuahua",
      "Mazatlan"                     => "America/Mazatlan",
      "Central Time (US & Canada)"   => "America/Chicago",
      "Saskatchewan"                 => "America/Regina",
      "Guadalajara"                  => "America/Mexico_City",
      "Mexico City"                  => "America/Mexico_City",
      "Monterrey"                    => "America/Monterrey",
      "Central America"              => "America/Guatemala",
      "Eastern Time (US & Canada)"   => "America/New_York",
      "Indiana (East)"               => "America/Indiana/Indianapolis",
      "Bogota"                       => "America/Bogota",
      "Lima"                         => "America/Lima",
      "Quito"                        => "America/Lima",
      "Atlantic Time (Canada)"       => "America/Halifax",
      "Caracas"                      => "America/Caracas",
      "La Paz"                       => "America/La_Paz",
      "Santiago"                     => "America/Santiago",
      "Newfoundland"                 => "America/St_Johns",
      "Brasilia"                     => "America/Sao_Paulo",
      "Buenos Aires"                 => "America/Argentina/Buenos_Aires",
      "Georgetown"                   => "America/Guyana",
      "Greenland"                    => "America/Godthab",
      "Mid-Atlantic"                 => "Atlantic/South_Georgia",
      "Azores"                       => "Atlantic/Azores",
      "Cape Verde Is."               => "Atlantic/Cape_Verde",
      "Dublin"                       => "Europe/Dublin",
      "Edinburgh"                    => "Europe/London",
      "Lisbon"                       => "Europe/Lisbon",
      "London"                       => "Europe/London",
      "Casablanca"                   => "Africa/Casablanca",
      "Monrovia"                     => "Africa/Monrovia",
      "UTC"                          => "Etc/UTC",
      "Belgrade"                     => "Europe/Belgrade",
      "Bratislava"                   => "Europe/Bratislava",
      "Budapest"                     => "Europe/Budapest",
      "Ljubljana"                    => "Europe/Ljubljana",
      "Prague"                       => "Europe/Prague",
      "Sarajevo"                     => "Europe/Sarajevo",
      "Skopje"                       => "Europe/Skopje",
      "Warsaw"                       => "Europe/Warsaw",
      "Zagreb"                       => "Europe/Zagreb",
      "Brussels"                     => "Europe/Brussels",
      "Copenhagen"                   => "Europe/Copenhagen",
      "Madrid"                       => "Europe/Madrid",
      "Paris"                        => "Europe/Paris",
      "Amsterdam"                    => "Europe/Amsterdam",
      "Berlin"                       => "Europe/Berlin",
      "Bern"                         => "Europe/Berlin",
      "Rome"                         => "Europe/Rome",
      "Stockholm"                    => "Europe/Stockholm",
      "Vienna"                       => "Europe/Vienna",
      "West Central Africa"          => "Africa/Algiers",
      "Bucharest"                    => "Europe/Bucharest",
      "Cairo"                        => "Africa/Cairo",
      "Helsinki"                     => "Europe/Helsinki",
      "Kyiv"                         => "Europe/Kiev",
      "Riga"                         => "Europe/Riga",
      "Sofia"                        => "Europe/Sofia",
      "Tallinn"                      => "Europe/Tallinn",
      "Vilnius"                      => "Europe/Vilnius",
      "Athens"                       => "Europe/Athens",
      "Istanbul"                     => "Europe/Istanbul",
      "Minsk"                        => "Europe/Minsk",
      "Jerusalem"                    => "Asia/Jerusalem",
      "Harare"                       => "Africa/Harare",
      "Pretoria"                     => "Africa/Johannesburg",
      "Moscow"                       => "Europe/Moscow",
      "St. Petersburg"               => "Europe/Moscow",
      "Volgograd"                    => "Europe/Moscow",
      "Kuwait"                       => "Asia/Kuwait",
      "Riyadh"                       => "Asia/Riyadh",
      "Nairobi"                      => "Africa/Nairobi",
      "Baghdad"                      => "Asia/Baghdad",
      "Tehran"                       => "Asia/Tehran",
      "Abu Dhabi"                    => "Asia/Muscat",
      "Muscat"                       => "Asia/Muscat",
      "Baku"                         => "Asia/Baku",
      "Tbilisi"                      => "Asia/Tbilisi",
      "Yerevan"                      => "Asia/Yerevan",
      "Kabul"                        => "Asia/Kabul",
      "Ekaterinburg"                 => "Asia/Yekaterinburg",
      "Islamabad"                    => "Asia/Karachi",
      "Karachi"                      => "Asia/Karachi",
      "Tashkent"                     => "Asia/Tashkent",
      "Chennai"                      => "Asia/Kolkata",
      "Kolkata"                      => "Asia/Kolkata",
      "Mumbai"                       => "Asia/Kolkata",
      "New Delhi"                    => "Asia/Kolkata",
      "Kathmandu"                    => "Asia/Kathmandu",
      "Astana"                       => "Asia/Dhaka",
      "Dhaka"                        => "Asia/Dhaka",
      "Sri Jayawardenepura"          => "Asia/Colombo",
      "Almaty"                       => "Asia/Almaty",
      "Novosibirsk"                  => "Asia/Novosibirsk",
      "Rangoon"                      => "Asia/Rangoon",
      "Bangkok"                      => "Asia/Bangkok",
      "Hanoi"                        => "Asia/Bangkok",
      "Jakarta"                      => "Asia/Jakarta",
      "Krasnoyarsk"                  => "Asia/Krasnoyarsk",
      "Beijing"                      => "Asia/Shanghai",
      "Chongqing"                    => "Asia/Chongqing",
      "Hong Kong"                    => "Asia/Hong_Kong",
      "Urumqi"                       => "Asia/Urumqi",
      "Kuala Lumpur"                 => "Asia/Kuala_Lumpur",
      "Singapore"                    => "Asia/Singapore",
      "Taipei"                       => "Asia/Taipei",
      "Perth"                        => "Australia/Perth",
      "Irkutsk"                      => "Asia/Irkutsk",
      "Ulaan Bataar"                 => "Asia/Ulaanbaatar",
      "Seoul"                        => "Asia/Seoul",
      "Osaka"                        => "Asia/Tokyo",
      "Sapporo"                      => "Asia/Tokyo",
      "Tokyo"                        => "Asia/Tokyo",
      "Yakutsk"                      => "Asia/Yakutsk",
      "Darwin"                       => "Australia/Darwin",
      "Adelaide"                     => "Australia/Adelaide",
      "Canberra"                     => "Australia/Melbourne",
      "Melbourne"                    => "Australia/Melbourne",
      "Sydney"                       => "Australia/Sydney",
      "Brisbane"                     => "Australia/Brisbane",
      "Hobart"                       => "Australia/Hobart",
      "Vladivostok"                  => "Asia/Vladivostok",
      "Guam"                         => "Pacific/Guam",
      "Port Moresby"                 => "Pacific/Port_Moresby",
      "Magadan"                      => "Asia/Magadan",
      "Solomon Is."                  => "Asia/Magadan",
      "New Caledonia"                => "Pacific/Noumea",
      "Fiji"                         => "Pacific/Fiji",
      "Kamchatka"                    => "Asia/Kamchatka",
      "Marshall Is."                 => "Pacific/Majuro",
      "Auckland"                     => "Pacific/Auckland",
      "Wellington"                   => "Pacific/Auckland",
      "Nuku'alofa"                   => "Pacific/Tongatapu"
    }.each { |name, zone| name.freeze; zone.freeze }
    MAPPING.freeze

    UTC_OFFSET_WITH_COLON = '%s%02d:%02d'
    UTC_OFFSET_WITHOUT_COLON = UTC_OFFSET_WITH_COLON.sub(':', '')

    # Assumes self represents an offset from UTC in seconds (as returned from Time#utc_offset)
    # and turns this into an +HH:MM formatted string. Example:
    #
    #   TimeZone.seconds_to_utc_offset(-21_600) # => "-06:00"
    def self.seconds_to_utc_offset(seconds, colon = true)
      format = colon ? UTC_OFFSET_WITH_COLON : UTC_OFFSET_WITHOUT_COLON
      sign = (seconds < 0 ? '-' : '+')
      hours = seconds.abs / 3600
      minutes = (seconds.abs % 3600) / 60
      format % [sign, hours, minutes]
    end

    include Comparable
    attr_reader :name
    attr_reader :tzinfo

    # Create a new TimeZone object with the given name and offset. The
    # offset is the number of seconds that this time zone is offset from UTC
    # (GMT). Seconds were chosen as the offset unit because that is the unit that
    # Ruby uses to represent time zone offsets (see Time#utc_offset).
    def initialize(name, utc_offset = nil, tzinfo = nil)
      self.class.send(:require_tzinfo)

      @name = name
      @utc_offset = utc_offset
      @tzinfo = tzinfo || TimeZone.find_tzinfo(name)
      @current_period = nil
    end

    def utc_offset
      if @utc_offset
        @utc_offset
      else
        @current_period ||= tzinfo.try(:current_period)
        @current_period.try(:utc_offset)
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
      result = (utc_offset <=> zone.utc_offset)
      result = (name <=> zone.name) if result == 0
      result
    end

    # Compare #name and TZInfo identifier to a supplied regexp, returning true
    # if a match is found.
    def =~(re)
      return true if name =~ re || MAPPING[name] =~ re
    end

    # Returns a textual representation of this time zone.
    def to_s
      "(GMT#{formatted_offset}) #{name}"
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone of +self+ from given values. Example:
    #
    #   Time.zone = "Hawaii"                      # => "Hawaii"
    #   Time.zone.local(2007, 2, 1, 15, 30, 45)   # => Thu, 01 Feb 2007 15:30:45 HST -10:00
    def local(*args)
      time = Time.utc_time(*args)
      ActiveSupport::TimeWithZone.new(nil, self, time)
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone of +self+ from number of seconds since the Unix epoch. Example:
    #
    #   Time.zone = "Hawaii"        # => "Hawaii"
    #   Time.utc(2000).to_f         # => 946684800.0
    #   Time.zone.at(946684800.0)   # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    def at(secs)
      utc = Time.at(secs).utc rescue DateTime.civil(1970).since(secs)
      utc.in_time_zone(self)
    end

    # Method for creating new ActiveSupport::TimeWithZone instance in time zone of +self+ from parsed string. Example:
    #
    #   Time.zone = "Hawaii"                      # => "Hawaii"
    #   Time.zone.parse('1999-12-31 14:00:00')    # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    #
    # If upper components are missing from the string, they are supplied from TimeZone#now:
    #
    #   Time.zone.now                 # => Fri, 31 Dec 1999 14:00:00 HST -10:00
    #   Time.zone.parse('22:30:00')   # => Fri, 31 Dec 1999 22:30:00 HST -10:00
    def parse(str, now=now)
      date_parts = Date._parse(str)
      return if date_parts.blank?
      time = Time.parse(str, now) rescue DateTime.parse(str)
      if date_parts[:offset].nil?
        ActiveSupport::TimeWithZone.new(nil, self, time)
      else
        time.in_time_zone(self)
      end
    end

    # Returns an ActiveSupport::TimeWithZone instance representing the current time
    # in the time zone represented by +self+. Example:
    #
    #   Time.zone = 'Hawaii'  # => "Hawaii"
    #   Time.zone.now         # => Wed, 23 Jan 2008 20:24:27 HST -10:00
    def now
      Time.now.utc.in_time_zone(self)
    end

    # Return the current date in this time zone.
    def today
      tzinfo.now.to_date
    end

    # Adjust the given time to the simultaneous time in the time zone represented by +self+. Returns a
    # Time.utc() instance -- if you want an ActiveSupport::TimeWithZone instance, use Time#in_time_zone() instead.
    def utc_to_local(time)
      tzinfo.utc_to_local(time)
    end

    # Adjust the given time to the simultaneous time in UTC. Returns a Time.utc() instance.
    def local_to_utc(time, dst=true)
      tzinfo.local_to_utc(time, dst)
    end

    # Available so that TimeZone instances respond like TZInfo::Timezone instances
    def period_for_utc(time)
      tzinfo.period_for_utc(time)
    end

    # Available so that TimeZone instances respond like TZInfo::Timezone instances
    def period_for_local(time, dst=true)
      tzinfo.period_for_local(time, dst)
    end

    def self.find_tzinfo(name)
      TZInfo::TimezoneProxy.new(MAPPING[name] || name)
    end

    class << self
      alias_method :create, :new

      # Return a TimeZone instance with the given name, or +nil+ if no
      # such TimeZone instance exists. (This exists to support the use of
      # this class with the +composed_of+ macro.)
      def new(name)
        self[name]
      end

      # Return an array of all TimeZone objects. There are multiple
      # TimeZone objects per time zone, in many cases, to make it easier
      # for users to find their own time zone.
      def all
        @zones ||= zones_map.values.sort
      end

      def zones_map
        @zones_map ||= begin
          new_zones_names = MAPPING.keys - lazy_zones_map.keys
          new_zones       = Hash[new_zones_names.map { |place| [place, create(place)] }]

          lazy_zones_map.merge(new_zones)
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
            lazy_zones_map[arg] ||= lookup(arg).tap { |tz| tz.utc_offset }
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

      protected

        def require_tzinfo
          require 'tzinfo' unless defined?(::TZInfo)
        rescue LoadError
          $stderr.puts "You don't have tzinfo installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

      private

        def lookup(name)
          (tzinfo = find_tzinfo(name)) && create(tzinfo.name.freeze)
        end

        def lazy_zones_map
          require_tzinfo

          @lazy_zones_map ||= Hash.new do |hash, place|
            hash[place] = create(place) if MAPPING.has_key?(place)
          end
        end
    end
  end
end
