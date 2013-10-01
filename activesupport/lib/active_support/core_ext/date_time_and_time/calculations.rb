module DateTimeAndTime
  module Calculations
    # Returns a new DateTime/Time representing the middle of the day (12:00)
    def middle_of_day
      change(:hour => 12)
    end
    alias :midday :middle_of_day
    alias :noon :middle_of_day
    alias :at_midday :middle_of_day
    alias :at_noon :middle_of_day
    alias :at_middle_of_day :middle_of_day

    # Returns a new DateTime/Time representing the start of the day (0:00).
    def beginning_of_day
      change(:hour => 0)
    end
    alias :midnight :beginning_of_day
    alias :at_midnight :beginning_of_day
    alias :at_beginning_of_day :beginning_of_day

    # Returns a new DateTime/Time representing the start of the hour (hh:00:00).
    def beginning_of_hour
      change(:min => 0)
    end
    alias :at_beginning_of_hour :beginning_of_hour

    # Returns a new DateTime/Time representing the start of the minute (hh:mm:00).
    def beginning_of_minute
      change(:sec => 0)
    end
    alias :at_beginning_of_minute :beginning_of_minute

    # Returns a new DateTime/Time representing the time a number of seconds ago, this is basically a wrapper around the Numeric extension
    # Do not use this method in combination with x.months, use months_ago instead!
    def ago(seconds)
      since(-seconds)
    end
  end
end
