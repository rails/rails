require File.dirname(__FILE__) + '/array/conversions'
require File.dirname(__FILE__) + '/array/grouping'
require File.dirname(__FILE__) + '/array/extract_options'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::Conversions
  include ActiveSupport::CoreExtensions::Array::Grouping
  include ActiveSupport::CoreExtensions::Array::ExtractOptions
end
