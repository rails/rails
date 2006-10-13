module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Makes it easier to access parts of a string, such as specific characters and substrings.
      module Access
        # Returns the character at the +position+ treating the string as an array (where 0 is the first character).
        #
        # Examples: 
        #   "hello".at(0)  # => "h"
        #   "hello".at(4)  # => "o"
        #   "hello".at(10) # => nil
        def at(position)
          chars[position, 1].to_s
        end
        
        # Returns the remaining of the string from the +position+ treating the string as an array (where 0 is the first character).
        #
        # Examples: 
        #   "hello".from(0)  # => "hello"
        #   "hello".from(2)  # => "llo"
        #   "hello".from(10) # => nil
        def from(position)
          chars[position..-1].to_s
        end
        
        # Returns the beginning of the string up to the +position+ treating the string as an array (where 0 is the first character).
        #
        # Examples: 
        #   "hello".to(0)  # => "h"
        #   "hello".to(2)  # => "hel"
        #   "hello".to(10) # => "hello"
        def to(position)
          chars[0..position].to_s
        end

        # Returns the first character of the string or the first +limit+ characters.
        #
        # Examples: 
        #   "hello".first     # => "h"
        #   "hello".first(2)  # => "he"
        #   "hello".first(10) # => "hello"
        def first(limit = 1)
          chars[0..(limit - 1)].to_s
        end
        
        # Returns the last character of the string or the last +limit+ characters.
        #
        # Examples: 
        #   "hello".last     # => "o"
        #   "hello".last(2)  # => "lo"
        #   "hello".last(10) # => "hello"
        def last(limit = 1)
          (chars[(-limit)..-1] || self).to_s
        end
      end
    end
  end
end
