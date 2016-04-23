require 'active_support/core_ext/date_and_time/compatibility'

class DateTime
  prepend DateAndTime::Compatibility
end
