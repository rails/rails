require 'date'
require File.dirname(__FILE__) + '/date/conversions'

class Date#:nodoc:
  include ActiveSupport::CoreExtensions::Date::Conversions
end
