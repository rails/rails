require 'date'
require "#{File.dirname(__FILE__)}/time/behavior"

DateTime.send(:include, ActiveSupport::CoreExtensions::Time::Behavior)
