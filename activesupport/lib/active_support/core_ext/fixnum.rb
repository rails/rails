require File.dirname(__FILE__) + '/fixnum/even_odd'

class Fixnum #:nodoc:
  include ActiveSupport::CoreExtensions::Fixnum::EvenOdd
end
