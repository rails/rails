require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # Form can be either :utc (default) or :local.
  def to_time(form = :utc)
    unless blank?
      date_values = ::Date._parse(self, false).
        values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset).
        map! { |arg| arg || 0 }
      date_values[6] *= 1000000
      offset = date_values.pop

      ::Time.send("#{form}_time", *date_values) - offset
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
