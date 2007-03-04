require 'date'
require "#{File.dirname(__FILE__)}/time/behavior"
require "#{File.dirname(__FILE__)}/date_time/calculations"
require "#{File.dirname(__FILE__)}/date_time/conversions"

DateTime.send(:include, ActiveSupport::CoreExtensions::Time::Behavior)
DateTime.send(:include, ActiveSupport::CoreExtensions::DateTime::Calculations)
DateTime.send(:include, ActiveSupport::CoreExtensions::DateTime::Conversions)
