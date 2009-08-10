# encoding: utf-8

module ActiveSupport #:nodoc:
  module Multibyte #:nodoc:
    # Chars enables you to work transparently with UTF-8 encoding in the Ruby String class without having extensive
    # knowledge about the encoding. A Chars object accepts a string upon initialization and proxies String methods in an
    # encoding safe manner. All the normal String methods are also implemented on the proxy.
    #
    # String methods are proxied through the Chars object, and can be accessed through the +mb_chars+ method. Methods
    # which would normally return a String object now return a Chars object so methods can be chained.
    #
    #   "The Perfect String  ".mb_chars.downcase.strip.normalize #=> "the perfect string"
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
      # Hangul character boundaries and properties
      HANGUL_SBASE = 0xAC00
      HANGUL_LBASE = 0x1100
      HANGUL_VBASE = 0x1161
      HANGUL_TBASE = 0x11A7
      HANGUL_LCOUNT = 19
      HANGUL_VCOUNT = 21
      HANGUL_TCOUNT = 28
      HANGUL_NCOUNT = HANGUL_VCOUNT * HANGUL_TCOUNT
      HANGUL_SCOUNT = 11172
      HANGUL_SLAST = HANGUL_SBASE + HANGUL_SCOUNT
      HANGUL_JAMO_FIRST = 0x1100
      HANGUL_JAMO_LAST = 0x11FF

      # All the unicode whitespace
      UNICODE_WHITESPACE = [
        (0x0009..0x000D).to_a, # White_Space # Cc   [5] <control-0009>..<control-000D>
        0x0020,                # White_Space # Zs       SPACE
        0x0085,                # White_Space # Cc       <control-0085>
        0x00A0,                # White_Space # Zs       NO-BREAK SPACE
        0x1680,                # White_Space # Zs       OGHAM SPACE MARK
        0x180E,                # White_Space # Zs       MONGOLIAN VOWEL SEPARATOR
        (0x2000..0x200A).to_a, # White_Space # Zs  [11] EN QUAD..HAIR SPACE
        0x2028,                # White_Space # Zl       LINE SEPARATOR
        0x2029,                # White_Space # Zp       PARAGRAPH SEPARATOR
        0x202F,                # White_Space # Zs       NARROW NO-BREAK SPACE
        0x205F,                # White_Space # Zs       MEDIUM MATHEMATICAL SPACE
        0x3000,                # White_Space # Zs       IDEOGRAPHIC SPACE
      ].flatten.freeze

      # BOM (byte order mark) can also be seen as whitespace, it's a non-rendering character used to distinguish
      # between little and big endian. This is not an issue in utf-8, so it must be ignored.
      UNICODE_LEADERS_AND_TRAILERS = UNICODE_WHITESPACE + [65279] # ZERO-WIDTH NO-BREAK SPACE aka BOM

      # Returns a regular expression pattern that matches the passed Unicode codepoints
      def self.codepoints_to_pattern(array_of_codepoints) #:nodoc:
        array_of_codepoints.collect{ |e| [e].pack 'U*' }.join('|')
      end
      UNICODE_TRAILERS_PAT = /(#{codepoints_to_pattern(UNICODE_LEADERS_AND_TRAILERS)})+\Z/
      UNICODE_LEADERS_PAT = /\A(#{codepoints_to_pattern(UNICODE_LEADERS_AND_TRAILERS)})+/

      # Borrowed from the Kconv library by Shinji KONO - (also as seen on the W3C site)
      UTF8_PAT = /\A(?:
                     [\x00-\x7f]                                     |
                     [\xc2-\xdf] [\x80-\xbf]                         |
                     \xe0        [\xa0-\xbf] [\x80-\xbf]             |
                     [\xe1-\xef] [\x80-\xbf] [\x80-\xbf]             |
                     \xf0        [\x90-\xbf] [\x80-\xbf] [\x80-\xbf] |
                     [\xf1-\xf3] [\x80-\xbf] [\x80-\xbf] [\x80-\xbf] |
                     \xf4        [\x80-\x8f] [\x80-\xbf] [\x80-\xbf]
                    )*\z/xn

      attr_reader :wrapped_string
      alias to_s wrapped_string
      alias to_str wrapped_string

      if '1.9'.respond_to?(:force_encoding)
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
        super || @wrapped_string.respond_to?(method, include_private) || false
      end

      # Enable more predictable duck-typing on String-like classes. See Object#acts_like?.
      def acts_like_string?
        true
      end

      # Returns +true+ if the Chars class can and should act as a proxy for the string _string_. Returns
      # +false+ otherwise.
      def self.wants?(string)
        $KCODE == 'UTF8' && consumes?(string)
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

      # Returns <tt>-1</tt>, <tt>0</tt> or <tt>+1</tt> depending on whether the Chars object is to be sorted before,
      # equal or after the object on the right side of the operation. It accepts any object that implements +to_s+.
      # See <tt>String#<=></tt> for more details.
      #
      # Example:
      #   'é'.mb_chars <=> 'ü'.mb_chars #=> -1
      def <=>(other)
        @wrapped_string <=> other.to_s
      end

      # Returns a new Chars object containing the _other_ object concatenated to the string.
      #
      # Example:
      #   ('Café'.mb_chars + ' périferôl').to_s #=> "Café périferôl"
      def +(other)
        self << other
      end

      # Like <tt>String#=~</tt> only it returns the character offset (in codepoints) instead of the byte offset.
      #
      # Example:
      #   'Café périferôl'.mb_chars =~ /ô/ #=> 12
      def =~(other)
        translate_offset(@wrapped_string =~ other)
      end

      # Works just like <tt>String#split</tt>, with the exception that the items in the resulting list are Chars
      # instances instead of String. This makes chaining methods easier.
      #
      # Example:
      #   'Café périferôl'.mb_chars.split(/é/).map { |part| part.upcase.to_s } #=> ["CAF", " P", "RIFERÔL"]
      def split(*args)
        @wrapped_string.split(*args).map { |i| i.mb_chars }
      end

      # Inserts the passed string at specified codepoint offsets.
      #
      # Example:
      #   'Café'.mb_chars.insert(4, ' périferôl').to_s #=> "Café périferôl"
      def insert(offset, fragment)
        unpacked = self.class.u_unpack(@wrapped_string)
        unless offset > unpacked.length
          @wrapped_string.replace(
            self.class.u_unpack(@wrapped_string).insert(offset, *self.class.u_unpack(fragment)).pack('U*')
          )
        else
          raise IndexError, "index #{offset} out of string"
        end
        self
      end

      # Returns +true+ if contained string contains _other_. Returns +false+ otherwise.
      #
      # Example:
      #   'Café'.mb_chars.include?('é') #=> true
      def include?(other)
        # We have to redefine this method because Enumerable defines it.
        @wrapped_string.include?(other)
      end

      # Returns the position _needle_ in the string, counting in codepoints. Returns +nil+ if _needle_ isn't found.
      #
      # Example:
      #   'Café périferôl'.mb_chars.index('ô') #=> 12
      #   'Café périferôl'.mb_chars.index(/\w/u) #=> 0
      def index(needle, offset=0)
        wrapped_offset = self.first(offset).wrapped_string.length
        index = @wrapped_string.index(needle, wrapped_offset)
        index ? (self.class.u_unpack(@wrapped_string.slice(0...index)).size) : nil
      end

      # Returns the position _needle_ in the string, counting in
      # codepoints, searching backward from _offset_ or the end of the
      # string. Returns +nil+ if _needle_ isn't found.
      #
      # Example:
      #   'Café périferôl'.mb_chars.rindex('é') #=> 6
      #   'Café périferôl'.mb_chars.rindex(/\w/u) #=> 13
      def rindex(needle, offset=nil)
        offset ||= length
        wrapped_offset = self.first(offset).wrapped_string.length
        index = @wrapped_string.rindex(needle, wrapped_offset)
        index ? (self.class.u_unpack(@wrapped_string.slice(0...index)).size) : nil
      end

      # Like <tt>String#[]=</tt>, except instead of byte offsets you specify character offsets.
      #
      # Example:
      #
      #   s = "Müller"
      #   s.mb_chars[2] = "e" # Replace character with offset 2
      #   s
      #   #=> "Müeler"
      #
      #   s = "Müller"
      #   s.mb_chars[1, 2] = "ö" # Replace 2 characters at character offset 1
      #   s
      #   #=> "Möler"
      def []=(*args)
        replace_by = args.pop
        # Indexed replace with regular expressions already works
        if args.first.is_a?(Regexp)
          @wrapped_string[*args] = replace_by
        else
          result = self.class.u_unpack(@wrapped_string)
          if args[0].is_a?(Fixnum)
            raise IndexError, "index #{args[0]} out of string" if args[0] >= result.length
            min = args[0]
            max = args[1].nil? ? min : (min + args[1] - 1)
            range = Range.new(min, max)
            replace_by = [replace_by].pack('U') if replace_by.is_a?(Fixnum)
          elsif args.first.is_a?(Range)
            raise RangeError, "#{args[0]} out of range" if args[0].min >= result.length
            range = args[0]
          else
            needle = args[0].to_s
            min = index(needle)
            max = min + self.class.u_unpack(needle).length - 1
            range = Range.new(min, max)
          end
          result[range] = self.class.u_unpack(replace_by)
          @wrapped_string.replace(result.pack('U*'))
        end
      end

      # Works just like <tt>String#rjust</tt>, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".mb_chars.rjust(8).to_s
      #   #=> "   ¾ cup"
      #
      #   "¾ cup".mb_chars.rjust(8, " ").to_s # Use non-breaking whitespace
      #   #=> "   ¾ cup"
      def rjust(integer, padstr=' ')
        justify(integer, :right, padstr)
      end

      # Works just like <tt>String#ljust</tt>, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".mb_chars.rjust(8).to_s
      #   #=> "¾ cup   "
      #
      #   "¾ cup".mb_chars.rjust(8, " ").to_s # Use non-breaking whitespace
      #   #=> "¾ cup   "
      def ljust(integer, padstr=' ')
        justify(integer, :left, padstr)
      end

      # Works just like <tt>String#center</tt>, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".mb_chars.center(8).to_s
      #   #=> " ¾ cup  "
      #
      #   "¾ cup".mb_chars.center(8, " ").to_s # Use non-breaking whitespace
      #   #=> " ¾ cup  "
      def center(integer, padstr=' ')
        justify(integer, :center, padstr)
      end

      # Strips entire range of Unicode whitespace from the right of the string.
      def rstrip
        chars(@wrapped_string.gsub(UNICODE_TRAILERS_PAT, ''))
      end
      
      # Strips entire range of Unicode whitespace from the left of the string.
      def lstrip
        chars(@wrapped_string.gsub(UNICODE_LEADERS_PAT, ''))
      end
      
      # Strips entire range of Unicode whitespace from the right and left of the string.
      def strip
        rstrip.lstrip
      end
      
      # Returns the number of codepoints in the string
      def size
        self.class.u_unpack(@wrapped_string).size
      end
      alias_method :length, :size
      
      # Reverses all characters in the string.
      #
      # Example:
      #   'Café'.mb_chars.reverse.to_s #=> 'éfaC'
      def reverse
        chars(self.class.u_unpack(@wrapped_string).reverse.pack('U*'))
      end
      
      # Implements Unicode-aware slice with codepoints. Slicing on one point returns the codepoints for that
      # character.
      #
      # Example:
      #   'こんにちは'.mb_chars.slice(2..3).to_s #=> "にち"
      def slice(*args)
        if args.size > 2
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" # Do as if we were native
        elsif (args.size == 2 && !(args.first.is_a?(Numeric) || args.first.is_a?(Regexp)))
          raise TypeError, "cannot convert #{args.first.class} into Integer" # Do as if we were native
        elsif (args.size == 2 && !args[1].is_a?(Numeric))
          raise TypeError, "cannot convert #{args[1].class} into Integer" # Do as if we were native
        elsif args[0].kind_of? Range
          cps = self.class.u_unpack(@wrapped_string).slice(*args)
          result = cps.nil? ? nil : cps.pack('U*')
        elsif args[0].kind_of? Regexp
          result = @wrapped_string.slice(*args)
        elsif args.size == 1 && args[0].kind_of?(Numeric)
          character = self.class.u_unpack(@wrapped_string)[args[0]]
          result = character.nil? ? nil : [character].pack('U')
        else
          result = self.class.u_unpack(@wrapped_string).slice(*args).pack('U*')
        end
        result.nil? ? nil : chars(result)
      end
      alias_method :[], :slice

      # Like <tt>String#slice!</tt>, except instead of byte offsets you specify character offsets.
      #
      # Example:
      #   s = 'こんにちは'
      #   s.mb_chars.slice!(2..3).to_s #=> "にち"
      #   s #=> "こんは"
      def slice!(*args)
        slice = self[*args]
        self[*args] = ''
        slice
      end

      # Returns the codepoint of the first character in the string.
      #
      # Example:
      #   'こんにちは'.mb_chars.ord #=> 12371
      def ord
        self.class.u_unpack(@wrapped_string)[0]
      end

      # Convert characters in the string to uppercase.
      #
      # Example:
      #   'Laurent, òu sont les tests?'.mb_chars.upcase.to_s #=> "LAURENT, ÒU SONT LES TESTS?"
      def upcase
        apply_mapping :uppercase_mapping
      end

      # Convert characters in the string to lowercase.
      #
      # Example:
      #   'VĚDA A VÝZKUM'.mb_chars.downcase.to_s #=> "věda a výzkum"
      def downcase
        apply_mapping :lowercase_mapping
      end

      # Converts the first character to uppercase and the remainder to lowercase.
      #
      # Example:
      #  'über'.mb_chars.capitalize.to_s #=> "Über"
      def capitalize
        (slice(0) || chars('')).upcase + (slice(1..-1) || chars('')).downcase
      end

      # Returns the KC normalization of the string by default. NFKC is considered the best normalization form for
      # passing strings to databases and validations.
      #
      # * <tt>str</tt> - The string to perform normalization on.
      # * <tt>form</tt> - The form you want to normalize in. Should be one of the following:
      #   <tt>:c</tt>, <tt>:kc</tt>, <tt>:d</tt>, or <tt>:kd</tt>. Default is
      #   ActiveSupport::Multibyte.default_normalization_form
      def normalize(form=ActiveSupport::Multibyte.default_normalization_form)
        # See http://www.unicode.org/reports/tr15, Table 1
        codepoints = self.class.u_unpack(@wrapped_string)
        chars(case form
          when :d
            self.class.reorder_characters(self.class.decompose_codepoints(:canonical, codepoints))
          when :c
            self.class.compose_codepoints(self.class.reorder_characters(self.class.decompose_codepoints(:canonical, codepoints)))
          when :kd
            self.class.reorder_characters(self.class.decompose_codepoints(:compatability, codepoints))
          when :kc
            self.class.compose_codepoints(self.class.reorder_characters(self.class.decompose_codepoints(:compatability, codepoints)))
          else
            raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end.pack('U*'))
      end

      # Performs canonical decomposition on all the characters.
      #
      # Example:
      #   'é'.length #=> 2
      #   'é'.mb_chars.decompose.to_s.length #=> 3
      def decompose
        chars(self.class.decompose_codepoints(:canonical, self.class.u_unpack(@wrapped_string)).pack('U*'))
      end

      # Performs composition on all the characters.
      #
      # Example:
      #   'é'.length #=> 3
      #   'é'.mb_chars.compose.to_s.length #=> 2
      def compose
        chars(self.class.compose_codepoints(self.class.u_unpack(@wrapped_string)).pack('U*'))
      end

      # Returns the number of grapheme clusters in the string.
      #
      # Example:
      #   'क्षि'.mb_chars.length #=> 4
      #   'क्षि'.mb_chars.g_length #=> 3
      def g_length
        self.class.g_unpack(@wrapped_string).length
      end

      # Replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent resulting in a valid UTF-8 string.
      def tidy_bytes
        chars(self.class.tidy_bytes(@wrapped_string))
      end

      %w(lstrip rstrip strip reverse upcase downcase tidy_bytes capitalize).each do |method|
        define_method("#{method}!") do |*args|
          unless args.nil?
            @wrapped_string = send(method, *args).to_s
          else
            @wrapped_string = send(method).to_s
          end
          self
        end
      end

      class << self

        # Unpack the string at codepoints boundaries. Raises an EncodingError when the encoding of the string isn't
        # valid UTF-8.
        #
        # Example:
        #   Chars.u_unpack('Café') #=> [67, 97, 102, 233]
        def u_unpack(string)
          begin
            string.unpack 'U*'
          rescue ArgumentError
            raise EncodingError, 'malformed UTF-8 character'
          end
        end

        # Detect whether the codepoint is in a certain character class. Returns +true+ when it's in the specified
        # character class and +false+ otherwise. Valid character classes are: <tt>:cr</tt>, <tt>:lf</tt>, <tt>:l</tt>,
        # <tt>:v</tt>, <tt>:lv</tt>, <tt>:lvt</tt> and <tt>:t</tt>.
        #
        # Primarily used by the grapheme cluster support.
        def in_char_class?(codepoint, classes)
          classes.detect { |c| UCD.boundary[c] === codepoint } ? true : false
        end

        # Unpack the string at grapheme boundaries. Returns a list of character lists.
        #
        # Example:
        #   Chars.g_unpack('क्षि') #=> [[2325, 2381], [2359], [2367]]
        #   Chars.g_unpack('Café') #=> [[67], [97], [102], [233]]
        def g_unpack(string)
          codepoints = u_unpack(string)
          unpacked = []
          pos = 0
          marker = 0
          eoc = codepoints.length
          while(pos < eoc)
            pos += 1
            previous = codepoints[pos-1]
            current = codepoints[pos]
            if (
                # CR X LF
                one = ( previous == UCD.boundary[:cr] and current == UCD.boundary[:lf] ) or
                # L X (L|V|LV|LVT)
                two = ( UCD.boundary[:l] === previous and in_char_class?(current, [:l,:v,:lv,:lvt]) ) or
                # (LV|V) X (V|T)
                three = ( in_char_class?(previous, [:lv,:v]) and in_char_class?(current, [:v,:t]) ) or
                # (LVT|T) X (T)
                four = ( in_char_class?(previous, [:lvt,:t]) and UCD.boundary[:t] === current ) or
                # X Extend
                five = (UCD.boundary[:extend] === current)
              )
            else
              unpacked << codepoints[marker..pos-1]
              marker = pos
            end
          end 
          unpacked
        end

        # Reverse operation of g_unpack.
        #
        # Example:
        #   Chars.g_pack(Chars.g_unpack('क्षि')) #=> 'क्षि'
        def g_pack(unpacked)
          (unpacked.flatten).pack('U*')
        end

        def padding(padsize, padstr=' ') #:nodoc:
          if padsize != 0
            new(padstr * ((padsize / u_unpack(padstr).size) + 1)).slice(0, padsize)
          else
            ''
          end
        end

        # Re-order codepoints so the string becomes canonical.
        def reorder_characters(codepoints)
          length = codepoints.length- 1
          pos = 0
          while pos < length do
            cp1, cp2 = UCD.codepoints[codepoints[pos]], UCD.codepoints[codepoints[pos+1]]
            if (cp1.combining_class > cp2.combining_class) && (cp2.combining_class > 0)
              codepoints[pos..pos+1] = cp2.code, cp1.code
              pos += (pos > 0 ? -1 : 1)
            else
              pos += 1
            end
          end
          codepoints
        end

        # Decompose composed characters to the decomposed form.
        def decompose_codepoints(type, codepoints)
          codepoints.inject([]) do |decomposed, cp|
            # if it's a hangul syllable starter character
            if HANGUL_SBASE <= cp and cp < HANGUL_SLAST
              sindex = cp - HANGUL_SBASE
              ncp = [] # new codepoints
              ncp << HANGUL_LBASE + sindex / HANGUL_NCOUNT
              ncp << HANGUL_VBASE + (sindex % HANGUL_NCOUNT) / HANGUL_TCOUNT
              tindex = sindex % HANGUL_TCOUNT
              ncp << (HANGUL_TBASE + tindex) unless tindex == 0
              decomposed.concat ncp
            # if the codepoint is decomposable in with the current decomposition type
            elsif (ncp = UCD.codepoints[cp].decomp_mapping) and (!UCD.codepoints[cp].decomp_type || type == :compatability)
              decomposed.concat decompose_codepoints(type, ncp.dup)
            else
              decomposed << cp
            end
          end
        end

        # Compose decomposed characters to the composed form.
        def compose_codepoints(codepoints)
          pos = 0
          eoa = codepoints.length - 1
          starter_pos = 0
          starter_char = codepoints[0]
          previous_combining_class = -1
          while pos < eoa
            pos += 1
            lindex = starter_char - HANGUL_LBASE
            # -- Hangul
            if 0 <= lindex and lindex < HANGUL_LCOUNT
              vindex = codepoints[starter_pos+1] - HANGUL_VBASE rescue vindex = -1
              if 0 <= vindex and vindex < HANGUL_VCOUNT
                tindex = codepoints[starter_pos+2] - HANGUL_TBASE rescue tindex = -1
                if 0 <= tindex and tindex < HANGUL_TCOUNT
                  j = starter_pos + 2
                  eoa -= 2
                else
                  tindex = 0
                  j = starter_pos + 1
                  eoa -= 1
                end
                codepoints[starter_pos..j] = (lindex * HANGUL_VCOUNT + vindex) * HANGUL_TCOUNT + tindex + HANGUL_SBASE
              end
              starter_pos += 1
              starter_char = codepoints[starter_pos]
            # -- Other characters
            else
              current_char = codepoints[pos]
              current = UCD.codepoints[current_char]
              if current.combining_class > previous_combining_class
                if ref = UCD.composition_map[starter_char]
                  composition = ref[current_char]
                else
                  composition = nil
                end
                unless composition.nil?
                  codepoints[starter_pos] = composition
                  starter_char = composition
                  codepoints.delete_at pos
                  eoa -= 1
                  pos -= 1
                  previous_combining_class = -1
                else
                  previous_combining_class = current.combining_class
                end
              else
                previous_combining_class = current.combining_class
              end
              if current.combining_class == 0
                starter_pos = pos
                starter_char = codepoints[pos]
              end
            end
          end
          codepoints
        end

        # Replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent resulting in a valid UTF-8 string.
        def tidy_bytes(string)
          string.split(//u).map do |c|
            c.force_encoding(Encoding::ASCII) if c.respond_to?(:force_encoding)

            if !UTF8_PAT.match(c)
              n = c.unpack('C')[0]
              n < 128 ? n.chr :
              n < 160 ? [UCD.cp1252[n] || n].pack('U') :
              n < 192 ? "\xC2" + n.chr : "\xC3" + (n-64).chr
            else
              c
            end
          end.join
        end
      end

      protected

        def translate_offset(byte_offset) #:nodoc:
          return nil if byte_offset.nil?
          return 0   if @wrapped_string == ''
          chunk = @wrapped_string[0..byte_offset]
          begin
            begin
              chunk.unpack('U*').length - 1
            rescue ArgumentError => e
              chunk = @wrapped_string[0..(byte_offset+=1)]
              # Stop retrying at the end of the string
              raise e unless byte_offset < chunk.length 
              # We damaged a character, retry
              retry
            end
          # Catch the ArgumentError so we can throw our own
          rescue ArgumentError 
            raise EncodingError, 'malformed UTF-8 character'
          end
        end

        def justify(integer, way, padstr=' ') #:nodoc:
          raise ArgumentError, "zero width padding" if padstr.length == 0
          padsize = integer - size
          padsize = padsize > 0 ? padsize : 0
          case way
          when :right
            result = @wrapped_string.dup.insert(0, self.class.padding(padsize, padstr))
          when :left
            result = @wrapped_string.dup.insert(-1, self.class.padding(padsize, padstr))
          when :center
            lpad = self.class.padding((padsize / 2.0).floor, padstr)
            rpad = self.class.padding((padsize / 2.0).ceil, padstr)
            result = @wrapped_string.dup.insert(0, lpad).insert(-1, rpad)
          end
          chars(result)
        end

        def apply_mapping(mapping) #:nodoc:
          chars(self.class.u_unpack(@wrapped_string).map do |codepoint|
            cp = UCD.codepoints[codepoint]
            if cp and (ncp = cp.send(mapping)) and ncp > 0
              ncp
            else
              codepoint
            end
          end.pack('U*'))
        end

        def chars(string) #:nodoc:
          self.class.new(string)
        end
    end
  end
end
