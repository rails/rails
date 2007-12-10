# A value object representing a time zone. A time zone is simply a named
# offset (in seconds) from GMT. Note that two time zone objects are only
# equivalent if they have both the same offset, and the same name.
#
# A TimeZone instance may be used to convert a Time value to the corresponding
# time zone.
#
# The class also includes #all, which returns a list of all TimeZone objects.
class TimeZone
  include Comparable

  attr_reader :name, :utc_offset

  # Create a new TimeZone object with the given name and offset. The offset is
  # the number of seconds that this time zone is offset from UTC (GMT). Seconds
  # were chosen as the offset unit because that is the unit that Ruby uses
  # to represent time zone offsets (see Time#utc_offset).
  def initialize(name, utc_offset)
    @name = name
    @utc_offset = utc_offset
  end

  # Returns the offset of this time zone as a formatted string, of the
  # format "+HH:MM". If the offset is zero, this returns the empty
  # string. If +colon+ is false, a colon will not be inserted into the
  # result.
  def formatted_offset( colon=true )
    return "" if utc_offset == 0
    sign = (utc_offset < 0 ? -1 : 1)
    hours = utc_offset.abs / 3600
    minutes = (utc_offset.abs % 3600) / 60
    "%+03d%s%02d" % [ hours * sign, colon ? ":" : "", minutes ]
  end

  # Compute and return the current time, in the time zone represented by
  # +self+.
  def now
    adjust(Time.now)
  end

  # Return the current date in this time zone.
  def today
    now.to_date
  end

  # Adjust the given time to the time zone represented by +self+.
  def adjust(time)
    time = time.to_time unless time.is_a?(::Time)
    time + utc_offset - time.utc_offset
  end

  # Reinterprets the given time value as a time in the current time
  # zone, and then adjusts it to return the corresponding time in the
  # local time zone.
  def unadjust(time)
    time = time.to_time unless time.is_a?(::Time)
    time = time.localtime
    time - utc_offset - time.utc_offset
  end

  # Compare this time zone to the parameter. The two are comapred first on
  # their offsets, and then by name.
  def <=>(zone)
    result = (utc_offset <=> zone.utc_offset)
    result = (name <=> zone.name) if result == 0
    result
  end

  # Returns a textual representation of this time zone.
  def to_s
    "(UTC#{formatted_offset}) #{name}"
  end

  @@zones = nil

  class << self
    # Create a new TimeZone instance with the given name and offset.
    def create(name, offset)
      zone = allocate
      zone.send!(:initialize, name, offset)
      zone
    end

    # Return a TimeZone instance with the given name, or +nil+ if no
    # such TimeZone instance exists. (This exists to support the use of
    # this class with the #composed_of macro.)
    def new(name)
      self[name]
    end

    # Return an array of all TimeZone objects. There are multiple TimeZone
    # objects per time zone, in many cases, to make it easier for users to
    # find their own time zone.
    def all
      unless @@zones
        @@zones = []
        [[-43_200, "International Date Line West" ],
         [-39_600, "Midway Island", "Samoa" ],
         [-36_000, "Hawaii" ],
         [-32_400, "Alaska" ],
         [-28_800, "Pacific Time (US & Canada)", "Tijuana" ],
         [-25_200, "Mountain Time (US & Canada)", "Chihuahua", "Mazatlan", 
                   "Arizona" ],
         [-21_600, "Central Time (US & Canada)", "Saskatchewan", "Guadalajara",
                   "Mexico City", "Monterrey", "Central America" ],
         [-18_000, "Eastern Time (US & Canada)", "Indiana (East)", "Bogota",
                   "Lima", "Quito" ],
         [-14_400, "Atlantic Time (Canada)", "Caracas", "La Paz", "Santiago" ],
         [-12_600, "Newfoundland" ],
         [-10_800, "Brasilia", "Buenos Aires", "Georgetown", "Greenland" ],
         [ -7_200, "Mid-Atlantic" ],
         [ -3_600, "Azores", "Cape Verde Is." ],
         [      0, "Dublin", "Edinburgh", "Lisbon", "London", "Casablanca",
                   "Monrovia" ],
         [  3_600, "Belgrade", "Bratislava", "Budapest", "Ljubljana", "Prague",
                   "Sarajevo", "Skopje", "Warsaw", "Zagreb", "Brussels",
                   "Copenhagen", "Madrid", "Paris", "Amsterdam", "Berlin",
                   "Bern", "Rome", "Stockholm", "Vienna",
                   "West Central Africa" ],
         [  7_200, "Bucharest", "Cairo", "Helsinki", "Kyev", "Riga", "Sofia",
                   "Tallinn", "Vilnius", "Athens", "Istanbul", "Minsk",
                   "Jerusalem", "Harare", "Pretoria" ],
         [ 10_800, "Moscow", "St. Petersburg", "Volgograd", "Kuwait", "Riyadh",
                   "Nairobi", "Baghdad" ],
         [ 12_600, "Tehran" ],
         [ 14_400, "Abu Dhabi", "Muscat", "Baku", "Tbilisi", "Yerevan" ],
         [ 16_200, "Kabul" ],
         [ 18_000, "Ekaterinburg", "Islamabad", "Karachi", "Tashkent" ],
         [ 19_800, "Chennai", "Kolkata", "Mumbai", "New Delhi" ],
         [ 20_700, "Kathmandu" ],
         [ 21_600, "Astana", "Dhaka", "Sri Jayawardenepura", "Almaty",
                   "Novosibirsk" ],
         [ 23_400, "Rangoon" ],
         [ 25_200, "Bangkok", "Hanoi", "Jakarta", "Krasnoyarsk" ],
         [ 28_800, "Beijing", "Chongqing", "Hong Kong", "Urumqi",
                   "Kuala Lumpur", "Singapore", "Taipei", "Perth", "Irkutsk",
                   "Ulaan Bataar" ],
         [ 32_400, "Seoul", "Osaka", "Sapporo", "Tokyo", "Yakutsk" ],
         [ 34_200, "Darwin", "Adelaide" ],
         [ 36_000, "Canberra", "Melbourne", "Sydney", "Brisbane", "Hobart",
                   "Vladivostok", "Guam", "Port Moresby" ],
         [ 39_600, "Magadan", "Solomon Is.", "New Caledonia" ],
         [ 43_200, "Fiji", "Kamchatka", "Marshall Is.", "Auckland",
                   "Wellington" ],
         [ 46_800, "Nuku'alofa" ]].
        each do |offset, *places|
          places.each { |place| @@zones << create(place, offset).freeze }
        end
        @@zones.sort!
      end
      @@zones
    end

    # Locate a specific time zone object. If the argument is a string, it
    # is interpreted to mean the name of the timezone to locate. If it is a
    # numeric value it is either the hour offset, or the second offset, of the
    # timezone to find. (The first one with that offset will be returned.)
    # Returns +nil+ if no such time zone is known to the system.
    def [](arg)
      case arg
        when String
          all.find { |z| z.name == arg }
        when Numeric
          arg *= 3600 if arg.abs <= 13
          all.find { |z| z.utc_offset == arg.to_i }
        else
          raise ArgumentError, "invalid argument to TimeZone[]: #{arg.inspect}"
      end
    end

    # A regular expression that matches the names of all time zones in
    # the USA.
    US_ZONES = /US|Arizona|Indiana|Hawaii|Alaska/ unless defined?(US_ZONES)

    # A convenience method for returning a collection of TimeZone objects
    # for time zones in the USA.
    def us_zones
      all.find_all { |z| z.name =~ US_ZONES }
    end
  end
end
