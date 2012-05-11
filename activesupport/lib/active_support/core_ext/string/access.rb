require 'active_support/multibyte'

class String
  # If you pass a single Fixnum, returns a substring of one character at that
  # position. The first character of the string is at position 0, the next at
  # position 1, and so on. If a range is supplied, a substring containing
  # characters at offsets given by the range is returned. In both cases, if an
  # offset is negative, it is counted from the end of the string. Returns nil
  # if the initial offset falls outside the string. Returns an empty string if
  # the beginning of the range is greater than the end of the string.
  #
  #   str = "hello"
  #   str.at(0)      #=> "h"
  #   str.at(1..3)   #=> "ell"
  #   str.at(-2)     #=> "l"
  #   str.at(-2..-1) #=> "lo"
  #   str.at(5)      #=> nil
  #   str.at(5..-1)  #=> ""
  #
  # If a Regexp is given, the matching portion of the string is returned.
  # If a String is given, that given string is returned if it occurs in
  # the string. In both cases, nil is returned if there is no match.
  #
  #   str = "hello"
  #   str.at(/lo/) #=> "lo"
  #   str.at(/ol/) #=> nil
  #   str.at("lo") #=> "lo"
  #   str.at("ol") #=> nil
  def at(position)
    self[position]
  end

  def from(position)
    self[position..-1]
  end

  # Returns the beginning of the string up to position. If the position is
  # negative, it is counted from the end of the string.
  #
  #   str = "hello"
  #   str.to(0)  #=> "h"
  #   str.to(3)  #=> "hell"
  #   str.to(-2) #=> "hell"
  #
  # You can mix it with +from+ method and do fun things like:
  #
  #   str = "hello"
  #   str.from(0).to(-1) #=> "hello"
  #   str.from(1).to(-2) #=> "ell"
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
