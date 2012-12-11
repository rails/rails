require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # Converts a string to a Time value.
  # The +form+ can be either :utc or :local (default :utc).
  #
  # The time is parsed using Date._parse method.
  # If +form+ is :local, then time is formatted using Time.zone
  #
  #   "3-2-2012".to_time                 # => 2012-02-03 00:00:00 UTC
  #   "12:20".to_time                    # => ArgumentError: invalid date
  #   "2012-12-13 06:12".to_time         # => 2012-12-13 06:12:00 UTC
  #   "2012-12-13T06:12".to_time         # => 2012-12-13 06:12:00 UTC
  #   "2012-12-13T06:12".to_time(:local) # => 2012-12-13 06:12:00 +0100
  def to_time(form = :utc)
    unless blank?
      date_values = ::Date._parse(self, false).
        values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset).
        map! { |arg| arg || 0 }
      date_values[6] *= 1000000
      offset = date_values.pop

      ::Time.send(form, *date_values) - offset
    end
  end

  # Converts a string to a Date value.
  #
  #   "1-1-2012".to_date   #=> Sun, 01 Jan 2012
  #   "01/01/2012".to_date #=> Sun, 01 Jan 2012
  #   "2012-12-13".to_date #=> Thu, 13 Dec 2012
  #   "12/13/2012".to_date #=> ArgumentError: invalid date
  def to_date
    unless blank?
      date_values = ::Date._parse(self, false).values_at(:year, :mon, :mday)

      ::Date.new(*date_values)
    end
  end

  # Converts a string to a DateTime value.
  #
  #   "1-1-2012".to_datetime            #=> Sun, 01 Jan 2012 00:00:00 +0000
  #   "01/01/2012 23:59:59".to_datetime #=> Sun, 01 Jan 2012 23:59:59 +0000
  #   "2012-12-13 12:50".to_datetime    #=> Thu, 13 Dec 2012 12:50:00 +0000
  #   "12/13/2012".to_datetime          #=> ArgumentError: invalid date
  def to_datetime
    unless blank?
      date_values = ::Date._parse(self, false).
        values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction).
        map! { |arg| arg || 0 }
      date_values[5] += date_values.pop

      ::DateTime.civil(*date_values)
    end
  end
end
