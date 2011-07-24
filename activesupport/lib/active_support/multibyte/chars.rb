# encoding: utf-8
require 'active_support/core_ext/string/access'
require 'active_support/core_ext/string/behavior'

module ActiveSupport #:nodoc:
  module Multibyte #:nodoc:
    # Chars enables you to work transparently with UTF-8 encoding in the Ruby String class without having extensive
    # knowledge about the encoding. A Chars object accepts a string upon initialization and proxies String methods in an
    # encoding safe manner. All the normal String methods are also implemented on the proxy.
    #
    # String methods are proxied through the Chars object, and can be accessed through the +mb_chars+ method. Methods
    # which would normally return a String object now return a Chars object so methods can be chained.
    #
    #   "The Perfect String  ".mb_chars.downcase.strip.normalize # => "the perfect string"
    #
    # Chars objects are perfectly interchangeable with String objects as long as no explicit class checks are made.
    # If certain methods do explicitly check the class, call +to_s+ before you pass chars objects to them.
    #
    #   bad.explicit_checking_method "T".mb_chars.downcase.to_s
    #
    # The default Chars implementation assumes that the encoding of the string is UTF-8, if you want to handle different
    # encodings you can write your own multibyte string handler and configure it through
    # ActiveSupport::Multibyte.proxy_class.
    #
    #   class CharsForUTF32
    #     def size
    #       @wrapped_string.size / 4
    #     end
    #
    #     def self.accepts?(string)
    #       string.length % 4 == 0
    #     end
    #   end
    #
    #   ActiveSupport::Multibyte.proxy_class = CharsForUTF32
    class Chars
      attr_reader :wrapped_string
      alias to_s wrapped_string
      alias to_str wrapped_string

      if RUBY_VERSION >= "1.9"
        # Creates a new Chars instance by wrapping _string_.
        def initialize(string)
          @wrapped_string = string
          @wrapped_string.force_encoding(Encoding::UTF_8) unless @wrapped_string.frozen?
        end
      else
        def initialize(string) #:nodoc:
          @wrapped_string = string
        end
      end

      # Forward all undefined methods to the wrapped string.
      def method_missing(method, *args, &block)
        if method.to_s =~ /!$/
          @wrapped_string.__send__(method, *args, &block)
          self
        else
          result = @wrapped_string.__send__(method, *args, &block)
          result.kind_of?(String) ? chars(result) : result
        end
      end

      # Returns +true+ if _obj_ responds to the given method. Private methods are included in the search
      # only if the optional second parameter evaluates to +true+.
      def respond_to?(method, include_private=false)
        super || @wrapped_string.respond_to?(method, include_private)
      end

      # Enable more predictable duck-typing on String-like classes. See Object#acts_like?.
      def acts_like_string?
        true
      end

      # Returns +true+ when the proxy class can handle the string. Returns +false+ otherwise.
      def self.consumes?(string)
        # Unpack is a little bit faster than regular expressions.
        string.unpack('U*')
        true
      rescue ArgumentError
        false
      end

      include Comparable

      # Returns -1, 0, or 1, depending on whether the Chars object is to be sorted before,
      # equal or after the object on the right side of the operation. It accepts any object
      # that implements +to_s+:
      #
      #   'é'.mb_chars <=> 'ü'.mb_chars # => -1
      #
      # See <tt>String#<=></tt> for more details.
      def <=>(other)
        @wrapped_string <=> other.to_s
      end

      if RUBY_VERSION < "1.9"
        # Returns +true+ if the Chars class can and should act as a proxy for the string _string_. Returns
        # +false+ otherwise.
        def self.wants?(string)
          $KCODE == 'UTF8' && consumes?(string)
        end

        # Returns a new Chars object containing the _other_ object concatenated to the string.
        #
        # Example:
        #   ('Café'.mb_chars + ' périferôl').to_s # => "Café périferôl"
        def +(other)
          chars(@wrapped_string + other)
        end

        # Like <tt>String#=~</tt> only it returns the character offset (in codepoints) instead of the byte offset.
        #
        # Example:
        #   'Café périferôl'.mb_chars =~ /ô/ # => 12
        def =~(other)
          translate_offset(@wrapped_string =~ other)
        end

        # Inserts the passed string at specified codepoint offsets.
        #
        # Example:
        #   'Café'.mb_chars.insert(4, ' périferôl').to_s # => "Café périferôl"
        def insert(offset, fragment)
          unpacked = Unicode.u_unpack(@wrapped_string)
          unless offset > unpacked.length
            @wrapped_string.replace(
              Unicode.u_unpack(@wrapped_string).insert(offset, *Unicode.u_unpack(fragment)).pack('U*')
            )
          else
            raise IndexError, "index #{offset} out of string"
          end
          self
        end

        # Returns +true+ if contained string contains _other_. Returns +false+ otherwise.
        #
        # Example:
        #   'Café'.mb_chars.include?('é') # => true
        def include?(other)
          # We have to redefine this method because Enumerable defines it.
          @wrapped_string.include?(other)
        end

        # Returns the position _needle_ in the string, counting in codepoints. Returns +nil+ if _needle_ isn't found.
        #
        # Example:
        #   'Café périferôl'.mb_chars.index('ô')   # => 12
        #   'Café périferôl'.mb_chars.index(/\w/u) # => 0
        def index(needle, offset=0)
          wrapped_offset = first(offset).wrapped_string.length
          index = @wrapped_string.index(needle, wrapped_offset)
          index ? (Unicode.u_unpack(@wrapped_string.slice(0...index)).size) : nil
        end

        # Returns the position _needle_ in the string, counting in
        # codepoints, searching backward from _offset_ or the end of the
        # string. Returns +nil+ if _needle_ isn't found.
        #
        # Example:
        #   'Café périferôl'.mb_chars.rindex('é')   # => 6
        #   'Café périferôl'.mb_chars.rindex(/\w/u) # => 13
        def rindex(needle, offset=nil)
          offset ||= length
          wrapped_offset = first(offset).wrapped_string.length
          index = @wrapped_string.rindex(needle, wrapped_offset)
          index ? (Unicode.u_unpack(@wrapped_string.slice(0...index)).size) : nil
        end

        # Returns the number of codepoints in the string
        def size
          Unicode.u_unpack(@wrapped_string).size
        end
        alias_method :length, :size

        # Strips entire range of Unicode whitespace from the right of the string.
        def rstrip
          chars(@wrapped_string.gsub(Unicode::TRAILERS_PAT, ''))
        end

        # Strips entire range of Unicode whitespace from the left of the string.
        def lstrip
          chars(@wrapped_string.gsub(Unicode::LEADERS_PAT, ''))
        end

        # Strips entire range of Unicode whitespace from the right and left of the string.
        def strip
          rstrip.lstrip
        end

        # Returns the codepoint of the first character in the string.
        #
        # Example:
        #   'こんにちは'.mb_chars.ord # => 12371
        def ord
          Unicode.u_unpack(@wrapped_string)[0]
        end

        # Works just like <tt>String#rjust</tt>, only integer specifies characters instead of bytes.
        #
        # Example:
        #
        #   "¾ cup".mb_chars.rjust(8).to_s
        #   # => "   ¾ cup"
        #
        #   "¾ cup".mb_chars.rjust(8, " ").to_s # Use non-breaking whitespace
        #   # => "   ¾ cup"
        def rjust(integer, padstr=' ')
          justify(integer, :right, padstr)
        end

        # Works just like <tt>String#ljust</tt>, only integer specifies characters instead of bytes.
        #
        # Example:
        #
        #   "¾ cup".mb_chars.rjust(8).to_s
        #   # => "¾ cup   "
        #
        #   "¾ cup".mb_chars.rjust(8, " ").to_s # Use non-breaking whitespace
        #   # => "¾ cup   "
        def ljust(integer, padstr=' ')
          justify(integer, :left, padstr)
        end

        # Works just like <tt>String#center</tt>, only integer specifies characters instead of bytes.
        #
        # Example:
        #
        #   "¾ cup".mb_chars.center(8).to_s
        #   # => " ¾ cup  "
        #
        #   "¾ cup".mb_chars.center(8, " ").to_s # Use non-breaking whitespace
        #   # => " ¾ cup  "
        def center(integer, padstr=' ')
          justify(integer, :center, padstr)
        end

      else
        def =~(other)
          @wrapped_string =~ other
        end
      end

      # Works just like <tt>String#split</tt>, with the exception that the items in the resulting list are Chars
      # instances instead of String. This makes chaining methods easier.
      #
      # Example:
      #   'Café périferôl'.mb_chars.split(/é/).map { |part| part.upcase.to_s } # => ["CAF", " P", "RIFERÔL"]
      def split(*args)
        @wrapped_string.split(*args).map { |i| i.mb_chars }
      end

      # Like <tt>String#[]=</tt>, except instead of byte offsets you specify character offsets.
      #
      # Example:
      #
      #   s = "Müller"
      #   s.mb_chars[2] = "e" # Replace character with offset 2
      #   s
      #   # => "Müeler"
      #
      #   s = "Müller"
      #   s.mb_chars[1, 2] = "ö" # Replace 2 characters at character offset 1
      #   s
      #   # => "Möler"
      def []=(*args)
        replace_by = args.pop
        # Indexed replace with regular expressions already works
        if args.first.is_a?(Regexp)
          @wrapped_string[*args] = replace_by
        else
          result = Unicode.u_unpack(@wrapped_string)
          case args.first
          when Fixnum
            raise IndexError, "index #{args[0]} out of string" if args[0] >= result.length
            min = args[0]
            max = args[1].nil? ? min : (min + args[1] - 1)
            range = Range.new(min, max)
            replace_by = [replace_by].pack('U') if replace_by.is_a?(Fixnum)
          when Range
            raise RangeError, "#{args[0]} out of range" if args[0].min >= result.length
            range = args[0]
          else
            needle = args[0].to_s
            min = index(needle)
            max = min + Unicode.u_unpack(needle).length - 1
            range = Range.new(min, max)
          end
          result[range] = Unicode.u_unpack(replace_by)
          @wrapped_string.replace(result.pack('U*'))
        end
      end

      # Reverses all characters in the string.
      #
      # Example:
      #   'Café'.mb_chars.reverse.to_s # => 'éfaC'
      def reverse
        chars(Unicode.g_unpack(@wrapped_string).reverse.flatten.pack('U*'))
      end

      # Implements Unicode-aware slice with codepoints. Slicing on one point returns the codepoints for that
      # character.
      #
      # Example:
      #   'こんにちは'.mb_chars.slice(2..3).to_s # => "にち"
      def slice(*args)
        if args.size > 2
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" # Do as if we were native
        elsif (args.size == 2 && !(args.first.is_a?(Numeric) || args.first.is_a?(Regexp)))
          raise TypeError, "cannot convert #{args.first.class} into Integer" # Do as if we were native
        elsif (args.size == 2 && !args[1].is_a?(Numeric))
          raise TypeError, "cannot convert #{args[1].class} into Integer" # Do as if we were native
        elsif args[0].kind_of? Range
          cps = Unicode.u_unpack(@wrapped_string).slice(*args)
          result = cps.nil? ? nil : cps.pack('U*')
        elsif args[0].kind_of? Regexp
          result = @wrapped_string.slice(*args)
        elsif args.size == 1 && args[0].kind_of?(Numeric)
          character = Unicode.u_unpack(@wrapped_string)[args[0]]
          result = character && [character].pack('U')
        else
          cps = Unicode.u_unpack(@wrapped_string).slice(*args)
          result = cps && cps.pack('U*')
        end
        result && chars(result)
      end
      alias_method :[], :slice

      # Limit the byte size of the string to a number of bytes without breaking characters. Usable
      # when the storage for a string is limited for some reason.
      #
      # Example:
      #   'こんにちは'.mb_chars.limit(7).to_s # => "こん"
      def limit(limit)
        slice(0...translate_offset(limit))
      end

      # Convert characters in the string to uppercase.
      #
      # Example:
      #   'Laurent, où sont les tests ?'.mb_chars.upcase.to_s # => "LAURENT, OÙ SONT LES TESTS ?"
      def upcase
        chars(Unicode.apply_mapping @wrapped_string, :uppercase_mapping)
      end

      # Convert characters in the string to lowercase.
      #
      # Example:
      #   'VĚDA A VÝZKUM'.mb_chars.downcase.to_s # => "věda a výzkum"
      def downcase
        chars(Unicode.apply_mapping @wrapped_string, :lowercase_mapping)
      end

      # Converts the first character to uppercase and the remainder to lowercase.
      #
      # Example:
      #  'über'.mb_chars.capitalize.to_s # => "Über"
      def capitalize
        (slice(0) || chars('')).upcase + (slice(1..-1) || chars('')).downcase
      end

      # Capitalizes the first letter of every word, when possible.
      #
      # Example:
      #   "ÉL QUE SE ENTERÓ".mb_chars.titleize    # => "Él Que Se Enteró"
      #   "日本語".mb_chars.titleize                 # => "日本語"
      def titleize
        chars(downcase.to_s.gsub(/\b('?[\S])/u) { Unicode.apply_mapping $1, :uppercase_mapping })
      end
      alias_method :titlecase, :titleize

      # Returns the KC normalization of the string by default. NFKC is considered the best normalization form for
      # passing strings to databases and validations.
      #
      # * <tt>form</tt> - The form you want to normalize in. Should be one of the following:
      #   <tt>:c</tt>, <tt>:kc</tt>, <tt>:d</tt>, or <tt>:kd</tt>. Default is
      #   ActiveSupport::Multibyte::Unicode.default_normalization_form
      def normalize(form = nil)
        chars(Unicode.normalize(@wrapped_string, form))
      end

      # Performs canonical decomposition on all the characters.
      #
      # Example:
      #   'é'.length                         # => 2
      #   'é'.mb_chars.decompose.to_s.length # => 3
      def decompose
        chars(Unicode.decompose_codepoints(:canonical, Unicode.u_unpack(@wrapped_string)).pack('U*'))
      end

      # Performs composition on all the characters.
      #
      # Example:
      #   'é'.length                       # => 3
      #   'é'.mb_chars.compose.to_s.length # => 2
      def compose
        chars(Unicode.compose_codepoints(Unicode.u_unpack(@wrapped_string)).pack('U*'))
      end

      # Returns the number of grapheme clusters in the string.
      #
      # Example:
      #   'क्षि'.mb_chars.length   # => 4
      #   'क्षि'.mb_chars.g_length # => 3
      def g_length
        Unicode.g_unpack(@wrapped_string).length
      end

      # Replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent resulting in a valid UTF-8 string.
      #
      # Passing +true+ will forcibly tidy all bytes, assuming that the string's encoding is entirely CP1252 or ISO-8859-1.
      def tidy_bytes(force = false)
        chars(Unicode.tidy_bytes(@wrapped_string, force))
      end

       %w(capitalize downcase lstrip reverse rstrip slice strip tidy_bytes upcase).each do |method|
        # Only define a corresponding bang method for methods defined in the proxy; On 1.9 the proxy will
        # exclude lstrip!, rstrip! and strip! because they are already work as expected on multibyte strings.
        if public_method_defined?(method)
          define_method("#{method}!") do |*args|
            @wrapped_string = send(args.nil? ? method : method, *args).to_s
            self
          end
        end
      end

      protected

        def translate_offset(byte_offset) #:nodoc:
          return nil if byte_offset.nil?
          return 0   if @wrapped_string == ''

          if @wrapped_string.respond_to?(:force_encoding)
            @wrapped_string = @wrapped_string.dup.force_encoding(Encoding::ASCII_8BIT)
          end

          begin
            @wrapped_string[0...byte_offset].unpack('U*').length
          rescue ArgumentError
            byte_offset -= 1
            retry
          end
        end

        def justify(integer, way, padstr=' ') #:nodoc:
          raise ArgumentError, "zero width padding" if padstr.length == 0
          padsize = integer - size
          padsize = padsize > 0 ? padsize : 0
          case way
          when :right
            result = @wrapped_string.dup.insert(0, padding(padsize, padstr))
          when :left
            result = @wrapped_string.dup.insert(-1, padding(padsize, padstr))
          when :center
            lpad = padding((padsize / 2.0).floor, padstr)
            rpad = padding((padsize / 2.0).ceil, padstr)
            result = @wrapped_string.dup.insert(0, lpad).insert(-1, rpad)
          end
          chars(result)
        end

        def padding(padsize, padstr=' ') #:nodoc:
          if padsize != 0
            chars(padstr * ((padsize / Unicode.u_unpack(padstr).size) + 1)).slice(0, padsize)
          else
            ''
          end
        end

        def chars(string) #:nodoc:
          self.class.new(string)
        end
    end
  end
end
