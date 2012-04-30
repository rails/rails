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
