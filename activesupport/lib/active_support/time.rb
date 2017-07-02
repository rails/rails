module ActiveSupport
  autoload :Duration, "active_support/duration"
  autoload :TimeWithZone, "active_support/time_with_zone"
  autoload :TimeZone, "active_support/values/time_zone"
end

require "date"
require "time"

require_relative "core_ext/time"
require_relative "core_ext/date"
require_relative "core_ext/date_time"

require_relative "core_ext/integer/time"
require_relative "core_ext/numeric/time"

require_relative "core_ext/string/conversions"
require_relative "core_ext/string/zones"
