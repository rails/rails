require File.dirname(__FILE__) + '/string/inflections'
require File.dirname(__FILE__) + '/string/conversions'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Inflections
  include ActiveSupport::CoreExtensions::String::Conversions
end
