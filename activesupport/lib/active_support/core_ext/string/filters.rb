require 'active_support/core_ext/string/multibyte'

class String
  # Returns the string, first removing all whitespace on both ends of
  # the string, and then changing remaining consecutive whitespace
  # groups into one space each.
  #
  # Examples:
  #   %{ Multi-line
  #      string }.squish                   # => "Multi-line string"
  #   " foo   bar    \n   \t   boo".squish # => "foo bar boo"
  def squish
    dup.squish!
  end

  # Performs a destructive squish. See String#squish.
  def squish!
    strip!
    gsub!(/\s+/, ' ')
    self
  end

  # Truncates a given +text+ after a given <tt>length</tt> if +text+ is longer than <tt>length</tt>:
  #
  #   "Once upon a time in a world far far away".truncate(27)
  #   # => "Once upon a time in a wo..."
  #
  # The last characters will be replaced with the <tt>:omission</tt> string (defaults to "...")
  # for a total length not exceeding <tt>:length</tt>:
  #
  #   "Once upon a time in a world far far away".truncate(27, :separator => ' ')
  #   # => "Once upon a time in a..."
  #
  # Pass a <tt>:separator</tt> to truncate +text+ at a natural break:
  #
  #   "And they found that many people were sleeping better.".truncate(25, :omission => "... (continued)")
  #   # => "And they f... (continued)"
  def truncate(length, options = {})
    text = self.dup
    options[:omission] ||= "..."

    length_with_room_for_omission = length - options[:omission].mb_chars.length
    chars = text.mb_chars
    stop = options[:separator] ?
      (chars.rindex(options[:separator].mb_chars, length_with_room_for_omission) || length_with_room_for_omission) : length_with_room_for_omission

    (chars.length > length ? chars[0...stop] + options[:omission] : text).to_s
  end
end
