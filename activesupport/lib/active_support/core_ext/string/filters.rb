# frozen_string_literal: true

class String
  # Returns the string, first removing all whitespace on both ends of
  # the string, and then changing remaining consecutive whitespace
  # groups into one space each.
  #
  # Note that it handles both ASCII and Unicode whitespace.
  #
  #   %{ Multi-line
  #      string }.squish                   # => "Multi-line string"
  #   " foo   bar    \n   \t   boo".squish # => "foo bar boo"
  def squish
    dup.squish!
  end

  # Performs a destructive squish. See String#squish.
  #   str = " foo   bar    \n   \t   boo"
  #   str.squish!                         # => "foo bar boo"
  #   str                                 # => "foo bar boo"
  def squish!
    gsub!(/[[:space:]]+/, " ")
    strip!
    self
  end

  # Returns a new string with all occurrences of the patterns removed.
  #   str = "foo bar test"
  #   str.remove(" test")                 # => "foo bar"
  #   str.remove(" test", /bar/)          # => "foo "
  #   str                                 # => "foo bar test"
  def remove(*patterns)
    dup.remove!(*patterns)
  end

  # Alters the string by removing all occurrences of the patterns.
  #   str = "foo bar test"
  #   str.remove!(" test", /bar/)         # => "foo "
  #   str                                 # => "foo "
  def remove!(*patterns)
    patterns.each do |pattern|
      gsub! pattern, ""
    end

    self
  end

  # Truncates a given +text+ to length <tt>truncate_to</tt> if +text+ is longer than <tt>truncate_to</tt>:
  #
  #   'Once upon a time in a world far far away'.truncate(27)
  #   # => "Once upon a time in a wo..."
  #
  # Pass a string or regexp <tt>:separator</tt> to truncate +text+ at a natural break:
  #
  #   'Once upon a time in a world far far away'.truncate(27, separator: ' ')
  #   # => "Once upon a time in a..."
  #
  #   'Once upon a time in a world far far away'.truncate(27, separator: /\s/)
  #   # => "Once upon a time in a..."
  #
  # The last characters will be replaced with the <tt>:omission</tt> string (defaults to "...").
  # The total length will not exceed <tt>truncate_to</tt> unless both +text+ and <tt>:omission</tt>
  # are longer than <tt>truncate_to</tt>:
  #
  #   'And they found that many people were sleeping better.'.truncate(25, omission: '... (continued)')
  #   # => "And they f... (continued)"
  #
  #   'And they found that many people were sleeping better.'.truncate(4, omission: '... (continued)')
  #   # => "... (continued)"
  def truncate(truncate_to, options = {})
    return dup unless length > truncate_to

    omission = options[:omission] || "..."
    length_with_room_for_omission = truncate_to - omission.length
    stop = \
      if options[:separator]
        rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
      else
        length_with_room_for_omission
      end

    +"#{self[0, stop]}#{omission}"
  end

  # Truncates +text+ to at most <tt>truncate_to</tt> bytes in length without
  # breaking string encoding by splitting multibyte characters or breaking
  # grapheme clusters ("perceptual characters") by truncating at combining
  # characters.
  #
  #   >> "🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪".size
  #   => 20
  #   >> "🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪".bytesize
  #   => 80
  #   >> "🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪🔪".truncate_bytes(20)
  #   => "🔪🔪🔪🔪…"
  #
  # The truncated text ends with the <tt>:omission</tt> string, defaulting
  # to "…", for a total length not exceeding <tt>truncate_to</tt>.
  #
  # Raises +ArgumentError+ when the bytesize of <tt>:omission</tt> exceeds <tt>truncate_to</tt>.
  def truncate_bytes(truncate_to, omission: "…")
    omission ||= ""

    case
    when bytesize <= truncate_to
      dup
    when omission.bytesize > truncate_to
      raise ArgumentError, "Omission #{omission.inspect} is #{omission.bytesize}, larger than the truncation length of #{truncate_to} bytes"
    when omission.bytesize == truncate_to
      omission.dup
    else
      self.class.new.force_encoding(encoding).tap do |cut|
        cut_at = truncate_to - omission.bytesize

        each_grapheme_cluster do |grapheme|
          if cut.bytesize + grapheme.bytesize <= cut_at
            cut << grapheme
          else
            break
          end
        end

        cut << omission
      end
    end
  end

  # Truncates a given +text+ after a given number of words (<tt>words_count</tt>):
  #
  #   'Once upon a time in a world far far away'.truncate_words(4)
  #   # => "Once upon a time..."
  #
  # Pass a string or regexp <tt>:separator</tt> to specify a different separator of words:
  #
  #   'Once<br>upon<br>a<br>time<br>in<br>a<br>world'.truncate_words(5, separator: '<br>')
  #   # => "Once<br>upon<br>a<br>time<br>in..."
  #
  # The last characters will be replaced with the <tt>:omission</tt> string (defaults to "..."):
  #
  #   'And they found that many people were sleeping better.'.truncate_words(5, omission: '... (continued)')
  #   # => "And they found that many... (continued)"
  def truncate_words(words_count, options = {})
    sep = options[:separator] || /\s+/
    sep = Regexp.escape(sep.to_s) unless Regexp === sep
    if self =~ /\A((?>.+?#{sep}){#{words_count - 1}}.+?)#{sep}.*/m
      $1 + (options[:omission] || "...")
    else
      dup
    end
  end
end
