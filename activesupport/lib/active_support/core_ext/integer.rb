require 'active_support/core_ext/integer/even_odd'
require 'active_support/core_ext/integer/inflections'
require 'active_support/core_ext/integer/time'

class Integer #:nodoc:
  include ActiveSupport::CoreExtensions::Integer::EvenOdd
  include ActiveSupport::CoreExtensions::Integer::Inflections
  include ActiveSupport::CoreExtensions::Integer::Time
end
