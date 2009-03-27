require 'date'

require 'active_support/core_ext/date_time/calculations'
require 'active_support/core_ext/date_time/zones'

require 'active_support/core_ext/time/behavior'
class DateTime
  include ActiveSupport::CoreExtensions::Time::Behavior
end

require 'active_support/core_ext/util'
ActiveSupport.core_ext DateTime, %w(conversions)
