require File.dirname(__FILE__) + '/string/inflections'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Inflections
end
