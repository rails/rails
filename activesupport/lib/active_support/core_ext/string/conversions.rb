require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # 'a'.ord == 'a'[0] for Ruby 1.9 forward compatibility.
  def ord
    self[0]
  end if RUBY_VERSION < '1.9'

  # Form can be either :utc (default) or :local.
  def to_time(form = :utc)
    ::Time.send("#{form}_time", *::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec).map { |arg| arg || 0 })
  end

  def to_date
    ::Date.new(*::Date._parse(self, false).values_at(:year, :mon, :mday))
  end

  def to_datetime
    ::DateTime.civil(*::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec).map { |arg| arg || 0 })
  end
end
