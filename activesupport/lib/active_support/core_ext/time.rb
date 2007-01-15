require File.dirname(__FILE__) + '/time/behavior'
require File.dirname(__FILE__) + '/time/calculations'
require File.dirname(__FILE__) + '/time/conversions'

class Time#:nodoc:
  include ActiveSupport::CoreExtensions::Time::Behavior
  include ActiveSupport::CoreExtensions::Time::Calculations
  include ActiveSupport::CoreExtensions::Time::Conversions
end
