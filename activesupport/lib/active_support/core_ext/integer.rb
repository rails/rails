require 'active_support/core_ext/integer/even_odd'
require 'active_support/core_ext/integer/inflections'

class Integer #:nodoc:
  include ActiveSupport::CoreExtensions::Integer::EvenOdd
  include ActiveSupport::CoreExtensions::Integer::Inflections
end
