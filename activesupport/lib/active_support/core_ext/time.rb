require File.dirname(__FILE__) + '/time/calculations'

class Time#:nodoc:
  include ActiveSupport::CoreExtensions::Time::Calculations
end
