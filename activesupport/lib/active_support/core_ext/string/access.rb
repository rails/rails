require "active_support/multibyte"

class String
  unless '1.9'.respond_to?(:force_encoding)
    # Returns the character at the +position+ treating the string as an array (where 0 is the first character).
    #
    # Examples:
    #   "hello".at(0)  # => "h"
    #   "hello".at(4)  # => "o"
    #   "hello".at(10) # => ERROR if < 1.9, nil in 1.9
    def at(position)
      mb_chars[position, 1].to_s
    end

    # Returns the remaining of the string from the +position+ treating the string as an array (where 0 is the first character).
    #
    # Examples:
    #   "hello".from(0)  # => "hello"
    #   "hello".from(2)  # => "llo"
    #   "hello".from(10) # => "" if < 1.9, nil in 1.9
    def from(position)
      mb_chars[position..-1].to_s
    end

    # Returns the beginning of the string up to the +position+ treating the string as an array (where 0 is the first character).
    #
    # Examples:
    #   "hello".to(0)  # => "h"
    #   "hello".to(2)  # => "hel"
    #   "hello".to(10) # => "hello"
    def to(position)
      mb_chars[0..position].to_s
    end

    # Returns the first character of the string or the first +limit+ characters.
    #
    # Examples:
    #   "hello".first     # => "h"
    #   "hello".first(2)  # => "he"
    #   "hello".first(10) # => "hello"
    def first(limit = 1)
      if limit == 0
        ''
      elsif limit >= size
        self
      else
        mb_chars[0...limit].to_s
      end
    end

    # Returns the last character of the string or the last +limit+ characters.
    #
    # Examples:
    #   "hello".last     # => "o"
    #   "hello".last(2)  # => "lo"
    #   "hello".last(10) # => "hello"
    def last(limit = 1)
      if limit == 0
        ''
      elsif limit >= size
        self
      else
        mb_chars[(-limit)..-1].to_s
      end
    end
  else
    def at(position)
      self[position]
    end

    def from(position)
      self[position..-1]
    end

    def to(position)
      self[0..position]
    end

    def first(limit = 1)
      if limit == 0
        ''
      elsif limit >= size
        self
      else
        to(limit - 1)
      end
    end

    def last(limit = 1)
      if limit == 0
        ''
      elsif limit >= size
        self
      else
        from(-limit)
      end
    end
  end
end
