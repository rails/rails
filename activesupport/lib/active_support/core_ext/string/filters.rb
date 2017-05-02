# encoding: utf-8
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

  # Truncates a given +text+ after a given <tt>length</tt> if +text+ is longer than <tt>length</tt>:
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
  # The last characters will be replaced with the <tt>:omission</tt> string (defaults to "...")
  # for a total length not exceeding <tt>length</tt>:
  #
  #   'And they found that many people were sleeping better.'.truncate(25, omission: '... (continued)')
  #   # => "And they f... (continued)"
  def truncate(truncate_at, options = {})
    return dup unless length > truncate_at

    omission = options[:omission] || "..."
    length_with_room_for_omission = truncate_at - omission.length
    stop = \
      if options[:separator]
        rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
      else
        length_with_room_for_omission
      end

    "#{self[0, stop]}#{omission}"
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
  
  # Mostly like <tt>truncate</tt>, but for longer text, and it truncate text with symbols like:
  # <tt>.</tt>, <tt>,</tt>, <tt>\n</tt> and so on.
  #    
  #    "The Model layer represents your domain model (such as Account, Product, Person, Post, etc.) and encapsulates the business logic that is specific to your application. In Rails, database-backed model classes are derived from ActiveRecord::Base. Active Record allows you to present the data from database rows as objects and embellish these data objects with business logic methods. Although most Rails models are backed by a database, models can also be ordinary Ruby classes, or Ruby classes that implement a set of interfaces as provided by the Active Model module. You can read more about Active Record in its README.".content_truncate(180)
  #    
  #    # => "The Model layer represents your domain model (such as Account, Product, Person, Post, etc.) and encapsulates the business logic that is specific to your application."
  #
  # And The result is truncated as close as limit_length for the first match separator. 
  #
  # Actually, it use "<br/>", "\n", "。", ".", " " as separators to truncate text. 
  #
  # If you don't want to use the default separators,
  # you can pass your favorite symbols with priority order as the <tt>:separators</tt>
  #
  def content_truncate limit_length, *separators
    sub_string = self.dup
    sep = separators.shift
    if sep
      sub_string.send(:smart_truncate, limit_length, sep, *separators)
    else
      sub_string.send(:smart_truncate, limit_length, "<br/>", "\n", "。", ".", " ")
    end
  end
  
  private
  def smart_truncate limit_length, sep, *separators
    while sep
      position = self.index(sep)||limit_length+1
      if position <= limit_length
        while position && position <= limit_length
          prev_index, position = position, self.index(sep, position+1)
        end
        return self[0...(prev_index+sep.length)].strip
      end
      sep = separators.shift
    end
    return self[0...limit_length].strip
  end
end
