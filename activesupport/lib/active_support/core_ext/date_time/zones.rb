require 'active_support/core_ext/time/zones'
require 'active_support/core_ext/time/in_time_zoneable'

class DateTime
  include ActiveSupport::InTimeZoneable
end
