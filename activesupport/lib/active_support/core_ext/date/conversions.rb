require 'date'
require 'active_support/inflector/methods'
require 'active_support/core_ext/date/zones'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/date_and_time/conversions'

class Date
  include DateAndTime::Conversions

  DATE_FORMATS = {
    :short        => '%e %b',
    :long         => '%B %e, %Y',
    :db           => '%Y-%m-%d',
    :number       => '%Y%m%d',
    :long_ordinal => lambda { |date|
      day_format = ActiveSupport::Inflector.ordinalize(date.day)
      date.strftime("%B #{day_format}, %Y") # => "April 25th, 2007"
    },
    :rfc822       => '%e %b %Y',
    :iso8601      => lambda { |date| date.iso8601 }
  }

  # Ruby 1.9 has Date#to_time which converts to localtime only.
  remove_method :to_time

  # Ruby 1.9 has Date#xmlschema which converts to a string without the time
  # component. This removal may generate an issue on FreeBSD, that's why we
  # need to use remove_possible_method here
  remove_possible_method :xmlschema

  # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005"
  def readable_inspect
    strftime('%a, %d %b %Y')
  end
  alias_method :default_inspect, :inspect
  alias_method :inspect, :readable_inspect

  # Converts a Date instance to a Time, where the time is set to the beginning of the day.
  # The timezone can be either :local or :utc (default :local).
  #
  #   date = Date.new(2007, 11, 10)  # => Sat, 10 Nov 2007
  #
  #   date.to_time                   # => Sat Nov 10 00:00:00 0800 2007
  #   date.to_time(:local)           # => Sat Nov 10 00:00:00 0800 2007
  #
  #   date.to_time(:utc)             # => Sat Nov 10 00:00:00 UTC 2007
  def to_time(form = :local)
    ::Time.send(form, year, month, day)
  end

  def xmlschema
    in_time_zone.xmlschema
  end
end
