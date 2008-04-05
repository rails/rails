module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      # Makes it easier to access parts of an array.
      module Access
        # Returns the tail of the array from +position+.
        #
        #   %w( a b c d ).from(0)  # => %w( a b c d )
        #   %w( a b c d ).from(2)  # => %w( c d )
        #   %w( a b c d ).from(10) # => nil
        def from(position)
          self[position..-1]
        end
        
        # Returns the beginning of the array up to +position+.
        #
        #   %w( a b c d ).to(0)  # => %w( a )
        #   %w( a b c d ).to(2)  # => %w( a b c )
        #   %w( a b c d ).to(10) # => %w( a b c d )
        def to(position)
          self[0..position]
        end
      end
    end
  end
end
