require File.dirname(__FILE__) + '/string/inflections'

class String
  include ActiveSupport::CoreExtensions::String::Inflections
end
