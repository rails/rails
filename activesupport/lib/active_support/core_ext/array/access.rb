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
        #   %w().from(0)           # => nil
        def from(position)
          self[position..-1]
        end
        
        # Returns the beginning of the array up to +position+.
        #
        #   %w( a b c d ).to(0)  # => %w( a )
        #   %w( a b c d ).to(2)  # => %w( a b c )
        #   %w( a b c d ).to(10) # => %w( a b c d )
        #   %w().to(0)           # => %w()
        def to(position)
          self[0..position]
        end

        # Equal to <tt>self[1]</tt>.
        def second
          self[1]
        end

        # Equal to <tt>self[2]</tt>.
        def third
          self[2]
        end

        # Equal to <tt>self[3]</tt>.
        def fourth
          self[3]
        end

        # Equal to <tt>self[4]</tt>.
        def fifth
          self[4]
        end

        # Equal to <tt>self[5]</tt>.
        def sixth
          self[5]
        end

        # Equal to <tt>self[6]</tt>.
        def seventh
          self[6]
        end

        # Equal to <tt>self[7]</tt>.
        def eighth
          self[7]
        end

        # Equal to <tt>self[8]</tt>.
        def ninth
          self[8]
        end

        # Equal to <tt>self[9]</tt>.
        def tenth
          self[9]
        end
      end
    end
  end
end
