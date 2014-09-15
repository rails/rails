# encoding: utf-8
module ActiveSupport
  module Multibyte
    module Unicode

      extend self

      # A list of all available normalization forms.
      # See http://www.unicode.org/reports/tr15/tr15-29.html for more
      # information about normalization.
      NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

      # The Unicode version that is supported by the implementation
      UNICODE_VERSION = '6.3.0'

      # The default normalization used for operations that require
      # normalization. It can be set to any of the normalizations
      # in NORMALIZATION_FORMS.
      #
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
        (0x2000..0x200A).to_a, # White_Space # Zs  [11] EN QUAD..HAIR SPACE
        0x2028,                # White_Space # Zl       LINE SEPARATOR
        0x2029,                # White_Space # Zp       PARAGRAPH SEPARATOR
        0x202F,                # White_Space # Zs       NARROW NO-BREAK SPACE
        0x205F,                # White_Space # Zs       MEDIUM MATHEMATICAL SPACE
        0x3000,                # White_Space # Zs       IDEOGRAPHIC SPACE
      ].flatten.freeze

      # BOM (byte order mark) can also be seen as whitespace, it's a
      # non-rendering character used to distinguish between little and big
      # endian. This is not an issue in utf-8, so it must be ignored.
      LEADERS_AND_TRAILERS = WHITESPACE + [65279] # ZERO-WIDTH NO-BREAK SPACE aka BOM

      # Returns a regular expression pattern that matches the passed Unicode
      # codepoints.
      def self.codepoints_to_pattern(array_of_codepoints) #:nodoc:
        array_of_codepoints.collect{ |e| [e].pack 'U*' }.join('|')
      end
      TRAILERS_PAT = /(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+\Z/u
      LEADERS_PAT = /\A(#{codepoints_to_pattern(LEADERS_AND_TRAILERS)})+/u

      # Detect whether the codepoint is in a certain character class. Returns
      # +true+ when it's in the specified character class and +false+ otherwise.
      # Valid character classes are: <tt>:cr</tt>, <tt>:lf</tt>, <tt>:l</tt>,
      # <tt>:v</tt>, <tt>:lv</tt>, <tt>:lvt</tt> and <tt>:t</tt>.
      #
      # Primarily used by the grapheme cluster support.
      def in_char_class?(codepoint, classes)
        classes.detect { |c| database.boundary[c] === codepoint } ? true : false
      end

      # Unpack the string at grapheme boundaries. Returns a list of character
      # lists.
      #
      #   Unicode.unpack_graphemes('क्षि') # => [[2325, 2381], [2359], [2367]]
      #   Unicode.unpack_graphemes('Café') # => [[67], [97], [102], [233]]
      def unpack_graphemes(string)
        codepoints = string.codepoints.to_a
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

      # Reverse operation of unpack_graphemes.
      #
      #   Unicode.pack_graphemes(Unicode.unpack_graphemes('क्षि')) # => 'क्षि'
      def pack_graphemes(unpacked)
        unpacked.flatten.pack('U*')
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
      def decompose(type, codepoints)
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
          elsif (ncp = database.codepoints[cp].decomp_mapping) and (!database.codepoints[cp].decomp_type || type == :compatibility)
            decomposed.concat decompose(type, ncp.dup)
          else
            decomposed << cp
          end
        end
      end

      # Compose decomposed characters to the composed form.
      def compose(codepoints)
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

      # Ruby >= 2.1 has String#scrub, which is faster than the workaround used for < 2.1.
      if '<3'.respond_to?(:scrub)
        # Replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent
        # resulting in a valid UTF-8 string.
        #
        # Passing +true+ will forcibly tidy all bytes, assuming that the string's
        # encoding is entirely CP1252 or ISO-8859-1.
        def tidy_bytes(string, force = false)
          return string if string.empty?
          return recode_windows1252_chars(string) if force
          string.scrub { |bad| recode_windows1252_chars(bad) }
        end
      else
        def tidy_bytes(string, force = false)
          return string if string.empty?
          return recode_windows1252_chars(string) if force

          # We can't transcode to the same format, so we choose a nearly-identical encoding.
          # We're going to 'transcode' bytes from UTF-8 when possible, then fall back to
          # CP1252 when we get errors. The final string will be 'converted' back to UTF-8
          # before returning.
          reader = Encoding::Converter.new(Encoding::UTF_8, Encoding::UTF_16LE)

          source = string.dup
          out = ''.force_encoding(Encoding::UTF_16LE)

          loop do
            reader.primitive_convert(source, out)
            _, _, _, error_bytes, _ = reader.primitive_errinfo
            break if error_bytes.nil?
            out << error_bytes.encode(Encoding::UTF_16LE, Encoding::Windows_1252, invalid: :replace, undef: :replace)
          end

          reader.finish

          out.encode!(Encoding::UTF_8)
        end
      end

      # Returns the KC normalization of the string by default. NFKC is
      # considered the best normalization form for passing strings to databases
      # and validations.
      #
      # * <tt>string</tt> - The string to perform normalization on.
      # * <tt>form</tt> - The form you want to normalize in. Should be one of
      #   the following: <tt>:c</tt>, <tt>:kc</tt>, <tt>:d</tt>, or <tt>:kd</tt>.
      #   Default is ActiveSupport::Multibyte.default_normalization_form.
      def normalize(string, form=nil)
        form ||= @default_normalization_form
        # See http://www.unicode.org/reports/tr15, Table 1
        codepoints = string.codepoints.to_a
        case form
          when :d
            reorder_characters(decompose(:canonical, codepoints))
          when :c
            compose(reorder_characters(decompose(:canonical, codepoints)))
          when :kd
            reorder_characters(decompose(:compatibility, codepoints))
          when :kc
            compose(reorder_characters(decompose(:compatibility, codepoints)))
          else
            raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end.pack('U*')
      end

      def downcase(string)
        apply_mapping string, :lowercase_mapping
      end

      def upcase(string)
        apply_mapping string, :uppercase_mapping
      end

      def swapcase(string)
        apply_mapping string, :swapcase_mapping
      end

      # Holds data about a codepoint in the Unicode database.
      class Codepoint
        attr_accessor :code, :combining_class, :decomp_type, :decomp_mapping, :uppercase_mapping, :lowercase_mapping

        # Initializing Codepoint object with default values
        def initialize
          @combining_class = 0
          @uppercase_mapping = 0
          @lowercase_mapping = 0
        end

        def swapcase_mapping
          uppercase_mapping > 0 ? uppercase_mapping : lowercase_mapping
        end
      end

      # Holds static data from the Unicode database.
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

        # Loads the Unicode database and returns all the internal objects of
        # UnicodeDatabase.
        def load
          begin
            @codepoints, @composition_exclusion, @composition_map, @boundary, @cp1252 = File.open(self.class.filename, 'rb') { |f| Marshal.load f.read }
          rescue => e
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

        # Returns the directory in which the data files are stored.
        def self.dirname
          File.dirname(__FILE__) + '/../values/'
        end

        # Returns the filename for the data file for this version.
        def self.filename
          File.expand_path File.join(dirname, "unicode_tables.dat")
        end
      end

      private

      def apply_mapping(string, mapping) #:nodoc:
        string.each_codepoint.map do |codepoint|
          cp = database.codepoints[codepoint]
          if cp and (ncp = cp.send(mapping)) and ncp > 0
            ncp
          else
            codepoint
          end
        end.pack('U*')
      end

      def recode_windows1252_chars(string)
        string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
      end

      def database
        @database ||= UnicodeDatabase.new
      end

    end
  end
end
