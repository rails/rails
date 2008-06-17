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

        # Equal to self[1]
        def second
          self[1]
        end

        # Equal to self[2]
        def third
          self[2]
        end

        # Equal to self[3]
        def fourth
          self[3]
        end

        # Equal to self[4]
        def fifth
          self[4]
        end

        # Equal to self[5]
        def sixth
          self[5]
        end

        # Equal to self[6]
        def seventh
          self[6]
        end

        # Equal to self[7]
        def eighth
          self[7]
        end

        # Equal to self[8]
        def ninth
          self[8]
        end

        # Equal to self[9]
        def tenth
          self[9]
        end
      end
    end
  end
end
