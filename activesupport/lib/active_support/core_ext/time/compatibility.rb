require 'active_support/core_ext/date_and_time/compatibility'

class Time
  prepend DateAndTime::Compatibility
end
