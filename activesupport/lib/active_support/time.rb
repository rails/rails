require 'active_support'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'active_support/core_ext/date_time'

module ActiveSupport
  autoload :Duration, 'active_support/duration'
  autoload :TimeWithZone, 'active_support/time_with_zone'
  autoload :TimeZone, 'active_support/values/time_zone'

  on_load_all do
    [Duration, TimeWithZone, TimeZone]
  end
end
