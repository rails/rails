require File.dirname(__FILE__) + '/fixnum/even_odd'
require File.dirname(__FILE__) + '/fixnum/inflections'

class Fixnum #:nodoc:
  include ActiveSupport::CoreExtensions::Fixnum::EvenOdd
  include ActiveSupport::CoreExtensions::Fixnum::Inflections
end

class Bignum #:nodoc:
  include ActiveSupport::CoreExtensions::Fixnum::EvenOdd
  include ActiveSupport::CoreExtensions::Fixnum::Inflections
end