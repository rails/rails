require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # 'a'.ord == 'a'[0] for Ruby 1.9 forward compatibility.
  def ord
    self[0]
  end unless method_defined?(:ord)

  # Form can be either :utc (default) or :local.
  def to_time(form = :utc)
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction).map { |arg| arg || 0 }
    d[6] *= 1000000
    ::Time.send("#{form}_time", *d)
  end

  def to_date
    ::Date.new(*::Date._parse(self, false).values_at(:year, :mon, :mday))
  end

  def to_datetime
    d = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction).map { |arg| arg || 0 }
    d[5] += d.pop
    ::DateTime.civil(*d)
  end
end
