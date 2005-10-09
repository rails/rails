require File.dirname(__FILE__) + '/range/conversions'

class Range #:nodoc:
  include ActiveSupport::CoreExtensions::Range::Conversions
end
