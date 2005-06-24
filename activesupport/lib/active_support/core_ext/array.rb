require File.dirname(__FILE__) + '/array/to_param'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::ToParam
end
