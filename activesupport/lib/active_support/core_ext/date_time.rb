require 'date'
require 'active_support/core_ext/time/behavior'
require 'active_support/core_ext/date_time/calculations'
require 'active_support/core_ext/date_time/conversions'

class DateTime
  include ActiveSupport::CoreExtensions::Time::Behavior
  include ActiveSupport::CoreExtensions::DateTime::Calculations
  include ActiveSupport::CoreExtensions::DateTime::Conversions
end
