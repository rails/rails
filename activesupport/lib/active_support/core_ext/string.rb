require File.dirname(__FILE__) + '/string/inflections'
require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/access'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Inflections
end
