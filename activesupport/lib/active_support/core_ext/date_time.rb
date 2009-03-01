require 'active_support/core_ext/util'
require 'date'
require 'active_support/core_ext/time/behavior'
require 'active_support/core_ext/time/zones'

class DateTime
  include ActiveSupport::CoreExtensions::Time::Behavior
  include ActiveSupport::CoreExtensions::Time::Zones
end

ActiveSupport.core_ext DateTime, %w(calculations conversions)
