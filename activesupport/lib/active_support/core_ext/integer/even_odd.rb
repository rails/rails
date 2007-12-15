module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Integer #:nodoc:
      # For checking if a fixnum is even or odd. 
      # * 1.even? # => false
      # * 1.odd?  # => true
      # * 2.even? # => true
      # * 2.odd? # => false
      module EvenOdd
        def multiple_of?(number)
          self % number == 0
        end

        def even?
          multiple_of? 2
        end if RUBY_VERSION < '1.9'

        def odd?
          !even?
        end if RUBY_VERSION < '1.9'
      end
    end
  end
end
