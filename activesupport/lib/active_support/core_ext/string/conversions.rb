require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # Form can be either :utc (default) or :local.
  def to_time(form = :utc)
    return nil if self.blank?
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset).map { |arg| arg || 0 }
    d[6] *= 1000000
    ::Time.send("#{form}_time", *d[0..6]) - d[7]
  end

  def to_date
    return nil if self.blank?
    ::Date.new(*::Date._parse(self, false).values_at(:year, :mon, :mday))
  end

  def to_datetime
    return nil if self.blank?
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction).map { |arg| arg || 0 }
    d[5] += d.pop
    ::DateTime.civil(*d)
  end
end
