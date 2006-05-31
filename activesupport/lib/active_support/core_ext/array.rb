require File.dirname(__FILE__) + '/array/conversions'
require File.dirname(__FILE__) + '/array/grouping'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::Conversions
  include ActiveSupport::CoreExtensions::Array::Grouping
end
