module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Fixnum #:nodoc:
      # For checking if a fixnum is even or odd. 
      # * 1.even? # => false
      # * 1.odd?  # => true
      # * 2.even? # => true
      # * 2.odd? # => false
      module EvenOdd
        def even?
          self % 2 == 0
        end
        
        def odd?
          !even?
        end
      end
    end
  end
end
