require 'date'
require 'active_support/inflector/methods'
require 'active_support/core_ext/date/zones'

class Date
  DATE_FORMATS = {
    :short        => "%e %b",
    :long         => "%B %e, %Y",
    :db           => "%Y-%m-%d",
    :number       => "%Y%m%d",
    :long_ordinal => lambda { |date| date.strftime("%B #{ActiveSupport::Inflector.ordinalize(date.day)}, %Y") }, # => "April 25th, 2007"
    :rfc822       => "%e %b %Y"
  }

  # Ruby 1.9 has Date#to_time which converts to localtime only.
  remove_method :to_time if method_defined?(:to_time)

  # Ruby 1.9 has Date#xmlschema which converts to a string without the time component.
  remove_method :xmlschema if method_defined?(:xmlschema)

  # Convert to a formatted string. See DATE_FORMATS for predefined formats.
  #
  # This method is aliased to <tt>to_s</tt>.
  #
  # ==== Examples
  #   date = Date.new(2007, 11, 10)       # => Sat, 10 Nov 2007
  #
  #   date.to_formatted_s(:db)            # => "2007-11-10"
  #   date.to_s(:db)                      # => "2007-11-10"
  #
  #   date.to_formatted_s(:short)         # => "10 Nov"
  #   date.to_formatted_s(:long)          # => "November 10, 2007"
  #   date.to_formatted_s(:long_ordinal)  # => "November 10th, 2007"
  #   date.to_formatted_s(:rfc822)        # => "10 Nov 2007"
  #
  # == Adding your own time formats to to_formatted_s
  # You can add your own formats to the Date::DATE_FORMATS hash.
  # Use the format name as the hash key and either a strftime string
  # or Proc instance that takes a date argument as the value.
  #
  #   # config/initializers/time_formats.rb
  #   Date::DATE_FORMATS[:month_and_year] = "%B %Y"
  #   Date::DATE_FORMATS[:short_ordinal] = lambda { |date| date.strftime("%B #{date.day.ordinalize}") }
  def to_formatted_s(format = :default)
    if formatter = DATE_FORMATS[format]
      if formatter.respond_to?(:call)
        formatter.call(self).to_s
      else
        strftime(formatter)
      end
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005"
  def readable_inspect
    strftime("%a, %d %b %Y")
  end
  alias_method :default_inspect, :inspect
  alias_method :inspect, :readable_inspect

  # A method to keep Time, Date and DateTime instances interchangeable on conversions.
  # In this case, it simply returns +self+.
  def to_date
    self
  end if RUBY_VERSION < '1.9'

  # Converts a Date instance to a Time, where the time is set to the beginning of the day.
  # The timezone can be either :local or :utc (default :local).
  #
  # ==== Examples
  #   date = Date.new(2007, 11, 10)  # => Sat, 10 Nov 2007
  #
  #   date.to_time                   # => Sat Nov 10 00:00:00 0800 2007
  #   date.to_time(:local)           # => Sat Nov 10 00:00:00 0800 2007
  #
  #   date.to_time(:utc)             # => Sat Nov 10 00:00:00 UTC 2007
  def to_time(form = :local)
    ::Time.send("#{form}_time", year, month, day)
  end

  # Converts a Date instance to a DateTime, where the time is set to the beginning of the day
  # and UTC offset is set to 0.
  #
  # ==== Examples
  #   date = Date.new(2007, 11, 10)  # => Sat, 10 Nov 2007
  #
  #   date.to_datetime               # => Sat, 10 Nov 2007 00:00:00 0000
  def to_datetime
    ::DateTime.civil(year, month, day, 0, 0, 0, 0)
  end if RUBY_VERSION < '1.9'

  def xmlschema
    to_time_in_current_zone.xmlschema
  end
end
