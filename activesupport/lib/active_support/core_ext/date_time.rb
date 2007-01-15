require "#{File.dirname(__FILE__)}/time/behavior"

class DateTime
  include ActiveSupport::CoreExtensions::Time::Behavior
end