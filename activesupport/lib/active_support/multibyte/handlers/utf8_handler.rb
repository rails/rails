# Contains all the handlers and helper classes
module ActiveSupport::Multibyte::Handlers #:nodoc:
  class EncodingError < ArgumentError #:nodoc:
  end
  
  class Codepoint #:nodoc:
    attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping
  end
  
  class UnicodeDatabase #:nodoc:
    attr_writer :codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252
    
    # self-expiring methods that lazily load the Unicode database and then return the value.
    [:codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252].each do |attr_name|
      class_eval(<<-EOS, __FILE__, __LINE__)
        def #{attr_name}
          load
          @#{attr_name}
        end
      EOS
    end
    
    # Shortcut to ucd.codepoints[]
    def [](index); codepoints[index]; end
    
    # Returns the directory in which the data files are stored
    def self.dirname
      File.dirname(__FILE__) + '/../../values/'
    end
    
    # Returns the filename for the data file for this version
    def self.filename
      File.expand_path File.join(dirname, "unicode_tables.dat")
    end
    
    # Loads the unicode database and returns all the internal objects of UnicodeDatabase
    # Once the values have been loaded, define attr_reader methods for the instance variables.
    def load
      begin
        @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, 'rb') { |f| Marshal.load f.read }
      rescue Exception => e
          raise IOError.new("Couldn't load the unicode tables for UTF8Handler (#{e.message}), handler is unusable")
      end
      @codepoints ||= Hash.new(Codepoint.new)
      @composition_exclusion ||= []
      @composition_map ||= {}
      @boundary ||= {}
      @cp1252 ||= {}
      
      # Redefine the === method so we can write shorter rules for grapheme cluster breaks
      @boundary.each do |k,_|
        @boundary[k].instance_eval do
          def ===(other)
            detect { |i| i === other } ? true : false
          end
        end if @boundary[k].kind_of?(Array)
      end

      # define attr_reader methods for the instance variables
      class << self
        attr_reader :codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252
      end
    end
  end
  
  # UTF8Handler implements Unicode aware operations for strings, these operations will be used by the Chars
  # proxy when $KCODE is set to 'UTF8'.
  class UTF8Handler
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
      (0x0009..0x000D).to_a,  # White_Space # Cc   [5] <control-0009>..<control-000D>
      0x0020,          # White_Space # Zs       SPACE
      0x0085,          # White_Space # Cc       <control-0085>
      0x00A0,          # White_Space # Zs       NO-BREAK SPACE
      0x1680,          # White_Space # Zs       OGHAM SPACE MARK
      0x180E,          # White_Space # Zs       MONGOLIAN VOWEL SEPARATOR
      (0x2000..0x200A).to_a, # White_Space # Zs  [11] EN QUAD..HAIR SPACE
      0x2028,          # White_Space # Zl       LINE SEPARATOR
      0x2029,          # White_Space # Zp       PARAGRAPH SEPARATOR
      0x202F,          # White_Space # Zs       NARROW NO-BREAK SPACE
      0x205F,          # White_Space # Zs       MEDIUM MATHEMATICAL SPACE
      0x3000,          # White_Space # Zs       IDEOGRAPHIC SPACE
    ].flatten.freeze
    
    # BOM (byte order mark) can also be seen as whitespace, it's a non-rendering character used to distinguish
    # between little and big endian. This is not an issue in utf-8, so it must be ignored.
    UNICODE_LEADERS_AND_TRAILERS = UNICODE_WHITESPACE + [65279] # ZERO-WIDTH NO-BREAK SPACE aka BOM
    
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
    
    # Returns a regular expression pattern that matches the passed Unicode codepoints
    def self.codepoints_to_pattern(array_of_codepoints) #:nodoc:
      array_of_codepoints.collect{ |e| [e].pack 'U*' }.join('|') 
    end
    UNICODE_TRAILERS_PAT = /(#{codepoints_to_pattern(UNICODE_LEADERS_AND_TRAILERS)})+\Z/
    UNICODE_LEADERS_PAT = /\A(#{codepoints_to_pattern(UNICODE_LEADERS_AND_TRAILERS)})+/
    
    class << self
      
      # ///
      # /// BEGIN String method overrides
      # ///
      
      # Inserts the passed string at specified codepoint offsets
      def insert(str, offset, fragment)
        str.replace(
          u_unpack(str).insert(
            offset,
            u_unpack(fragment)
          ).flatten.pack('U*')
        )
      end
      
      # Returns the position of the passed argument in the string, counting in codepoints
      def index(str, *args)
        bidx = str.index(*args)
        bidx ? (u_unpack(str.slice(0...bidx)).size) : nil
      end
      
      # Works just like the indexed replace method on string, except instead of byte offsets you specify
      # character offsets.
      #
      # Example:
      #
      #   s = "Müller"
      #   s.chars[2] = "e" # Replace character with offset 2
      #   s
      #   #=> "Müeler"
      #
      #   s = "Müller"
      #   s.chars[1, 2] = "ö" # Replace 2 characters at character offset 1
      #   s
      #   #=> "Möler"
      def []=(str, *args)
        replace_by = args.pop
        # Indexed replace with regular expressions already works
        return str[*args] = replace_by if args.first.is_a?(Regexp)
        result = u_unpack(str)
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
          min = index(str, needle)
          max = min + length(needle) - 1
          range = Range.new(min, max)
        end
        result[range] = u_unpack(replace_by)
        str.replace(result.pack('U*'))
      end
      
      # Works just like String#rjust, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".chars.rjust(8).to_s
      #   #=> "   ¾ cup"
      #
      #   "¾ cup".chars.rjust(8, " ").to_s # Use non-breaking whitespace
      #   #=> "   ¾ cup"
      def rjust(str, integer, padstr=' ')
        justify(str, integer, :right, padstr)
      end
      
      # Works just like String#ljust, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".chars.rjust(8).to_s
      #   #=> "¾ cup   "
      #
      #   "¾ cup".chars.rjust(8, " ").to_s # Use non-breaking whitespace
      #   #=> "¾ cup   "
      def ljust(str, integer, padstr=' ')
        justify(str, integer, :left, padstr)
      end
      
      # Works just like String#center, only integer specifies characters instead of bytes.
      #
      # Example:
      #
      #   "¾ cup".chars.center(8).to_s
      #   #=> " ¾ cup  "
      #
      #   "¾ cup".chars.center(8, " ").to_s # Use non-breaking whitespace
      #   #=> " ¾ cup  "
      def center(str, integer, padstr=' ')
        justify(str, integer, :center, padstr)
      end
      
      # Does Unicode-aware rstrip
      def rstrip(str)
        str.gsub(UNICODE_TRAILERS_PAT, '')
      end
      
      # Does Unicode-aware lstrip
      def lstrip(str)
        str.gsub(UNICODE_LEADERS_PAT, '')
      end
      
      # Removed leading and trailing whitespace
      def strip(str)
        str.gsub(UNICODE_LEADERS_PAT, '').gsub(UNICODE_TRAILERS_PAT, '')
      end
      
      # Returns the number of codepoints in the string
      def size(str)
        u_unpack(str).size
      end
      alias_method :length, :size
      
      # Reverses codepoints in the string.
      def reverse(str)
        u_unpack(str).reverse.pack('U*')
      end
      
      # Implements Unicode-aware slice with codepoints. Slicing on one point returns the codepoints for that
      # character.
      def slice(str, *args)
        if args.size > 2
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" # Do as if we were native
        elsif (args.size == 2 && !(args.first.is_a?(Numeric) || args.first.is_a?(Regexp)))
          raise TypeError, "cannot convert #{args.first.class} into Integer" # Do as if we were native
        elsif (args.size == 2 && !args[1].is_a?(Numeric))
          raise TypeError, "cannot convert #{args[1].class} into Integer" # Do as if we were native
        elsif args[0].kind_of? Range
          cps = u_unpack(str).slice(*args)
          cps.nil? ? nil : cps.pack('U*')
        elsif args[0].kind_of? Regexp
          str.slice(*args)
        elsif args.size == 1 && args[0].kind_of?(Numeric)
          u_unpack(str)[args[0]]
        else
          u_unpack(str).slice(*args).pack('U*')
        end
      end
      alias_method :[], :slice
      
      # Convert characters in the string to uppercase
      def upcase(str); to_case :uppercase_mapping, str; end
      
      # Convert characters in the string to lowercase
      def downcase(str); to_case :lowercase_mapping, str; end
      
      # Returns a copy of +str+ with the first character converted to uppercase and the remainder to lowercase
      def capitalize(str)
        upcase(slice(str, 0..0)) + downcase(slice(str, 1..-1) || '')
      end
      
      # ///
      # /// Extra String methods for unicode operations
      # ///
      
      # Returns the KC normalization of the string by default. NFKC is considered the best normalization form for
      # passing strings to databases and validations.
      #
      # * <tt>str</tt> - The string to perform normalization on.
      # * <tt>form</tt> - The form you want to normalize in. Should be one of the following: :c, :kc, :d or :kd.
      def normalize(str, form=ActiveSupport::Multibyte::DEFAULT_NORMALIZATION_FORM)
        # See http://www.unicode.org/reports/tr15, Table 1
        codepoints = u_unpack(str)
        case form
          when :d
            reorder_characters(decompose_codepoints(:canonical, codepoints))
          when :c
            compose_codepoints reorder_characters(decompose_codepoints(:canonical, codepoints))
          when :kd
            reorder_characters(decompose_codepoints(:compatability, codepoints))
          when :kc
            compose_codepoints reorder_characters(decompose_codepoints(:compatability, codepoints))
          else
            raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end.pack('U*')
      end
      
      # Perform decomposition on the characters in the string
      def decompose(str)
        decompose_codepoints(:canonical, u_unpack(str)).pack('U*')
      end
      
      # Perform composition on the characters in the string
      def compose(str)
        compose_codepoints u_unpack(str).pack('U*')
      end
      
      # ///
      # /// BEGIN Helper methods for unicode operation
      # ///
      
      # Used to translate an offset from bytes to characters, for instance one received from a regular expression match
      def translate_offset(str, byte_offset)
        return nil if byte_offset.nil?
        return 0 if str == ''
        chunk = str[0..byte_offset]
        begin
          begin
            chunk.unpack('U*').length - 1
          rescue ArgumentError => e
            chunk = str[0..(byte_offset+=1)]
            # Stop retrying at the end of the string
            raise e unless byte_offset < chunk.length 
            # We damaged a character, retry
            retry
          end
        # Catch the ArgumentError so we can throw our own
        rescue ArgumentError 
          raise EncodingError.new('malformed UTF-8 character')
        end
      end
      
      # Checks if the string is valid UTF8.
      def consumes?(str)
        # Unpack is a little bit faster than regular expressions
        begin
          str.unpack('U*')
          true
        rescue ArgumentError
          false
        end
      end
      
      # Returns the number of grapheme clusters in the string. This method is very likely to be moved or renamed
      # in future versions.
      def g_length(str)
        g_unpack(str).length
      end
      
      # Replaces all the non-utf-8 bytes by their iso-8859-1 or cp1252 equivalent resulting in a valid utf-8 string
      def tidy_bytes(str)
        str.split(//u).map do |c|
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
      
      protected
      
      # Detect whether the codepoint is in a certain character class. Primarily used by the
      # grapheme cluster support.
      def in_char_class?(codepoint, classes)
        classes.detect { |c| UCD.boundary[c] === codepoint } ? true : false
      end
      
      # Unpack the string at codepoints boundaries
      def u_unpack(str)
        begin
          str.unpack 'U*'
        rescue ArgumentError
          raise EncodingError.new('malformed UTF-8 character')
        end
      end
      
      # Unpack the string at grapheme boundaries instead of codepoint boundaries
      def g_unpack(str)
        codepoints = u_unpack(str)
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
      
      # Reverse operation of g_unpack
      def g_pack(unpacked)
        unpacked.flatten
      end
      
      # Justifies a string in a certain way. Valid values for <tt>way</tt> are <tt>:right</tt>, <tt>:left</tt> and
      # <tt>:center</tt>. Is primarily used as a helper method by <tt>rjust</tt>, <tt>ljust</tt> and <tt>center</tt>.
      def justify(str, integer, way, padstr=' ')
        raise ArgumentError, "zero width padding" if padstr.length == 0
        padsize = integer - size(str)
        padsize = padsize > 0 ? padsize : 0
        case way
        when :right
          str.dup.insert(0, padding(padsize, padstr))
        when :left
          str.dup.insert(-1, padding(padsize, padstr))
        when :center
          lpad = padding((padsize / 2.0).floor, padstr)
          rpad = padding((padsize / 2.0).ceil, padstr)
          str.dup.insert(0, lpad).insert(-1, rpad)
        end
      end
      
      # Generates a padding string of a certain size.
      def padding(padsize, padstr=' ')
        if padsize != 0
          slice(padstr * ((padsize / size(padstr)) + 1), 0, padsize)
        else
          ''
        end
      end
      
      # Convert characters to a different case
      def to_case(way, str)
        u_unpack(str).map do |codepoint|
          cp = UCD[codepoint] 
          unless cp.nil?
            ncp = cp.send(way)
            ncp > 0 ? ncp : codepoint
          else
            codepoint
          end
        end.pack('U*')
      end
      
      # Re-order codepoints so the string becomes canonical
      def reorder_characters(codepoints)
        length = codepoints.length- 1
        pos = 0
        while pos < length do
          cp1, cp2 = UCD[codepoints[pos]], UCD[codepoints[pos+1]]
          if (cp1.combining_class > cp2.combining_class) && (cp2.combining_class > 0)
            codepoints[pos..pos+1] = cp2.code, cp1.code
            pos += (pos > 0 ? -1 : 1)
          else
            pos += 1
          end
        end
        codepoints
      end
      
      # Decompose composed characters to the decomposed form
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
          elsif (ncp = UCD[cp].decomp_mapping) and (!UCD[cp].decomp_type || type == :compatability)
            decomposed.concat decompose_codepoints(type, ncp.dup)
          else
            decomposed << cp
          end
        end
      end
      
      # Compose decomposed characters to the composed form
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
            current = UCD[current_char]
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
      
      # UniCode Database
      UCD = UnicodeDatabase.new
    end
  end
end
