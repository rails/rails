require "active_support/core_ext/date_and_time/compatibility"
require "active_support/core_ext/module/remove_method"

class Time
  include DateAndTime::Compatibility

  remove_possible_method :to_time

  def to_time
    preserve_timezone ? self : getlocal
  end
end
