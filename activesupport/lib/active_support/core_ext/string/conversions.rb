require 'date'
require 'active_support/core_ext/time/calculations'

class String
  # Attempts to converts itself to a <tt>Time</tt> object and
  # returns <tt>nil</tt> if it can't.
  # <tt>form</tt> can be either :utc (default) or :local.
  def to_time(form = :utc)
    return nil if self.blank?
    parts = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset)
    return nil unless parts.any?
    parts.map! {|part| part || 0 }
    parts[6] *= 1000000
    ::Time.send("#{form}_time", *parts[0..6]) - parts[7]
  end

  # Attempts to converts itself to a <tt>Date</tt> object and
  # returns <tt>nil</tt> if it can't.
  def to_date
    return nil if self.blank?
    parts = ::Date._parse(self, false).values_at(:year, :mon, :mday)
    return nil unless parts.any?
    ::Date.new(*parts)
  end

  # Attempts to converts itself to a <tt>DateTime</tt> object and
  # returns <tt>nil</tt> if it can't.
  def to_datetime
    return nil if self.blank?
    parts = ::Date._parse(self, false).values_at(:year, :mon, :mday, :hour, :min, :sec, :zone, :sec_fraction)
    return nil unless parts.any?
    parts.map! {|part| part || 0 }
    parts[5] += parts.pop
    ::DateTime.civil(*parts)
  end
end
