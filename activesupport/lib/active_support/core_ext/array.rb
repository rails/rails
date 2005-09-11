require File.dirname(__FILE__) + '/array/conversions'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::Conversions
end
