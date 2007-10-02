require 'date'
require 'active_support/core_ext/date/behavior'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date/conversions'

class Date#:nodoc:
  include ActiveSupport::CoreExtensions::Date::Behavior
  include ActiveSupport::CoreExtensions::Date::Calculations
  include ActiveSupport::CoreExtensions::Date::Conversions
end
