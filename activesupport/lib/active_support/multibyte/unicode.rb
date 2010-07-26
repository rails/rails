module ActiveSupport
  module Multibyte
    module Unicode

      extend self

      # A list of all available normalization forms. See http://www.unicode.org/reports/tr15/tr15-29.html for more
      # information about normalization.
      NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

      # The Unicode version that is supported by the implementation
      UNICODE_VERSION = '5.2.0'

      # The default normalization used for operations that require normalization. It can be set to any of the
      # normalizations in NORMALIZATION_FORMS.
      #
      # Example:
      #   ActiveSupport::Multibyte::Unicode.default_normalization_form = :c
      attr_accessor :default_normalization_form
      @default_normalization_form = :kc

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
      WHITESPACE = [
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
      LEADERS_AND_TRAILERS = WHITESPACE + [65279] # ZERO-WIDTH NO-BREAK SPACE aka BOM

      # Returns a regular expression pattern that matches the passed Unicode codepoints
      def self.codepoints_to_pattern(array_of_codepoints) #:nodoc:
        array_of_codepoints.collect{ |e| [e].pack 'U*' }.join('|')
      end
      TRAILERS_PAT = /(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+\Z/u
      LEADERS_PAT = /\A(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+/u

      # Unpack the string at codepoints boundaries. Raises an EncodingError when the encoding of the string isn't
      # valid UTF-8.
      #
      # Example:
      #   Unicode.u_unpack('Café') #=> [67, 97, 102, 233]
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
        classes.detect { |c| database.boundary[c] === codepoint } ? true : false
      end

      # Unpack the string at grapheme boundaries. Returns a list of character lists.
      #
      # Example:
      #   Unicode.g_unpack('क्षि') #=> [[2325, 2381], [2359], [2367]]
      #   Unicode.g_unpack('Café') #=> [[67], [97], [102], [233]]
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
              ( previous == database.boundary[:cr] and current == database.boundary[:lf] ) or
              # L X (L|V|LV|LVT)
              ( database.boundary[:l] === previous and in_char_class?(current, [:l,:v,:lv,:lvt]) ) or
              # (LV|V) X (V|T)
              ( in_char_class?(previous, [:lv,:v]) and in_char_class?(current, [:v,:t]) ) or
              # (LVT|T) X (T)
              ( in_char_class?(previous, [:lvt,:t]) and database.boundary[:t] === current ) or
              # X Extend
              (database.boundary[:extend] === current)
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
      #   Unicode.g_pack(Unicode.g_unpack('क्षि')) #=> 'क्षि'
      def g_pack(unpacked)
        (unpacked.flatten).pack('U*')
      end

      # Re-order codepoints so the string becomes canonical.
      def reorder_characters(codepoints)
        length = codepoints.length- 1
        pos = 0
        while pos < length do
          cp1, cp2 = database.codepoints[codepoints[pos]], database.codepoints[codepoints[pos+1]]
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
          elsif (ncp = database.codepoints[cp].decomp_mapping) and (!database.codepoints[cp].decomp_type || type == :compatability)
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
            current = database.codepoints[current_char]
            if current.combining_class > previous_combining_class
              if ref = database.composition_map[starter_char]
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
      #
      # Passing +true+ will forcibly tidy all bytes, assuming that the string's encoding is entirely CP1252 or ISO-8859-1.
      def tidy_bytes(string, force = false)
        if force
          return string.unpack("C*").map do |b|
            tidy_byte(b)
          end.flatten.compact.pack("C*").unpack("U*").pack("U*")
        end

        bytes = string.unpack("C*")
        conts_expected = 0
        last_lead = 0

        bytes.each_index do |i|

          byte          = bytes[i]
          is_cont       = byte > 127 && byte < 192
          is_lead       = byte > 191 && byte < 245
          is_unused     = byte > 240
          is_restricted = byte > 244

          # Impossible or highly unlikely byte? Clean it.
          if is_unused || is_restricted
            bytes[i] = tidy_byte(byte)
          elsif is_cont
            # Not expecting contination byte? Clean up. Otherwise, now expect one less.
            conts_expected == 0 ? bytes[i] = tidy_byte(byte) : conts_expected -= 1
          else
            if conts_expected > 0
              # Expected continuation, but got ASCII or leading? Clean backwards up to
              # the leading byte.
              (1..(i - last_lead)).each {|j| bytes[i - j] = tidy_byte(bytes[i - j])}
              conts_expected = 0
            end
            if is_lead
              # Final byte is leading? Clean it.
              if i == bytes.length - 1
                bytes[i] = tidy_byte(bytes.last)
              else
                # Valid leading byte? Expect continuations determined by position of
                # first zero bit, with max of 3.
                conts_expected = byte < 224 ? 1 : byte < 240 ? 2 : 3
                last_lead = i
              end
            end
          end
        end
        bytes.empty? ? "" : bytes.flatten.compact.pack("C*").unpack("U*").pack("U*")
      end

      # Returns the KC normalization of the string by default. NFKC is considered the best normalization form for
      # passing strings to databases and validations.
      #
      # * <tt>string</tt> - The string to perform normalization on.
      # * <tt>form</tt> - The form you want to normalize in. Should be one of the following:
      #   <tt>:c</tt>, <tt>:kc</tt>, <tt>:d</tt>, or <tt>:kd</tt>. Default is
      #   ActiveSupport::Multibyte.default_normalization_form
      def normalize(string, form=nil)
        form ||= @default_normalization_form
        # See http://www.unicode.org/reports/tr15, Table 1
        codepoints = u_unpack(string)
        case form
          when :d
            reorder_characters(decompose_codepoints(:canonical, codepoints))
          when :c
            compose_codepoints(reorder_characters(decompose_codepoints(:canonical, codepoints)))
          when :kd
            reorder_characters(decompose_codepoints(:compatability, codepoints))
          when :kc
            compose_codepoints(reorder_characters(decompose_codepoints(:compatability, codepoints)))
          else
            raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end.pack('U*')
      end

      def apply_mapping(string, mapping) #:nodoc:
        u_unpack(string).map do |codepoint|
          cp = database.codepoints[codepoint]
          if cp and (ncp = cp.send(mapping)) and ncp > 0
            ncp
          else
            codepoint
          end
        end.pack('U*')
      end

      # Holds data about a codepoint in the Unicode database
      class Codepoint
        attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping
      end

      # Holds static data from the Unicode database
      class UnicodeDatabase
        ATTRIBUTES = :codepoints, :composition_exclusion, :composition_map, :boundary, :cp1252

        attr_writer(*ATTRIBUTES)

        def initialize
          @codepoints = Hash.new(Codepoint.new)
          @composition_exclusion = []
          @composition_map = {}
          @boundary = {}
          @cp1252 = {}
        end

        # Lazy load the Unicode database so it's only loaded when it's actually used
        ATTRIBUTES.each do |attr_name|
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            def #{attr_name}     # def codepoints
              load               #   load
              @#{attr_name}      #   @codepoints
            end                  # end
          EOS
        end

        # Loads the Unicode database and returns all the internal objects of UnicodeDatabase.
        def load
          begin
            @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, 'rb') { |f| Marshal.load f.read }
          rescue Exception => e
              raise IOError.new("Couldn't load the Unicode tables for UTF8Handler (#{e.message}), ActiveSupport::Multibyte is unusable")
          end

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
            attr_reader(*ATTRIBUTES)
          end
        end

        # Returns the directory in which the data files are stored
        def self.dirname
          File.dirname(__FILE__) + '/../values/'
        end

        # Returns the filename for the data file for this version
        def self.filename
          File.expand_path File.join(dirname, "unicode_tables.dat")
        end
      end

      private

      def tidy_byte(byte)
        if byte < 160
          [database.cp1252[byte] || byte].pack("U").unpack("C*")
        elsif byte < 192
          [194, byte]
        else
          [195, byte - 64]
        end
      end

      def database
        @database ||= UnicodeDatabase.new
      end

    end
  end
end
