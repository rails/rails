# encoding: utf-8
class String
  # Returns the string, first removing all whitespace on both ends of
  # the string, and then changing remaining consecutive whitespace
  # groups into one space each.
  #
  # Note that it handles both ASCII and Unicode whitespace like mongolian vowel separator (U+180E).
  #
  #   %{ Multi-line
  #      string }.squish                   # => "Multi-line string"
  #   " foo   bar    \n   \t   boo".squish # => "foo bar boo"
  def squish
    dup.squish!
  end

  # Performs a destructive squish. See String#squish.
  def squish!
    gsub!(/\A[[:space:]]+/, '')
    gsub!(/[[:space:]]+\z/, '')
    gsub!(/[[:space:]]+/, ' ')
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

    options[:omission] ||= '...'
    length_with_room_for_omission = truncate_at - options[:omission].length
    stop = \
      if options[:separator]
        rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
      else
        length_with_room_for_omission
      end

    "#{self[0...stop]}#{options[:omission]}"
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
