require File.dirname(__FILE__) + '/integer/even_odd'
require File.dirname(__FILE__) + '/integer/inflections'

class Integer #:nodoc:
  include ActiveSupport::CoreExtensions::Integer::EvenOdd
  include ActiveSupport::CoreExtensions::Integer::Inflections
end
