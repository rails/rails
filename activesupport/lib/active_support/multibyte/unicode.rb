require "active_support/multibyte/unicode/backend"

module ActiveSupport
  module Multibyte
    module Unicode
      extend self

      # A list of all available normalization forms.
      # See http://www.unicode.org/reports/tr15/tr15-29.html for more
      # information about normalization.
      NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

      class << self
        def backend=(backend)
          if defined? @backend_module
            (@backend_module.instance_methods(false) + @backend_module.private_instance_methods(false)).each do |m|
              Unicode.__send__(:undef_method, m)
            end
            @backend_module.constants.each do |c|
              Unicode.__send__(:remove_const, c)
            end
          end

          @backend_module = Backend.lookup(backend)

          (@backend_module.instance_methods(false) + @backend_module.private_instance_methods(false)).each do |m|
            Unicode.__send__(:undef_method, m) if Unicode.method_defined?(m)
            Unicode.__send__(:define_method, m, @backend_module.instance_method(m))
          end
          @backend_module.constants.each do |c|
            Unicode.const_set(c, @backend_module.const_get(c))
          end
        end
      end

      # The default normalization used for operations that require
      # normalization. It can be set to any of the normalizations
      # in NORMALIZATION_FORMS.
      #
      #   ActiveSupport::Multibyte::Unicode.default_normalization_form = :c
      attr_accessor :default_normalization_form
      @default_normalization_form = :kc

      # Detect whether the codepoint is in a certain character class. Returns
      # +true+ when it's in the specified character class and +false+ otherwise.
      # Valid character classes are: <tt>:cr</tt>, <tt>:lf</tt>, <tt>:l</tt>,
      # <tt>:v</tt>, <tt>:lv</tt>, <tt>:lvt</tt> and <tt>:t</tt>.
      #
      # Primarily used by the grapheme cluster support.
      def in_char_class?(codepoint, classes)
        raise NotImplementedError
      end

      # Unpack the string at grapheme boundaries. Returns a list of character
      # lists.
      #
      #   Unicode.unpack_graphemes('क्षि') # => [[2325, 2381], [2359], [2367]]
      #   Unicode.unpack_graphemes('Café') # => [[67], [97], [102], [233]]
      def unpack_graphemes(string)
        raise NotImplementedError
      end

      # Reverse operation of unpack_graphemes.
      #
      #   Unicode.pack_graphemes(Unicode.unpack_graphemes('क्षि')) # => 'क्षि'
      def pack_graphemes(unpacked)
        raise NotImplementedError
      end

      # Re-order codepoints so the string becomes canonical.
      def reorder_characters(codepoints)
        raise NotImplementedError
      end

      # Decompose composed characters to the decomposed form.
      def decompose(type, codepoints)
        raise NotImplementedError
      end

      # Compose decomposed characters to the composed form.
      def compose(codepoints)
        raise NotImplementedError
      end

      # Returns the KC normalization of the string by default. NFKC is
      # considered the best normalization form for passing strings to databases
      # and validations.
      #
      # * <tt>string</tt> - The string to perform normalization on.
      # * <tt>form</tt> - The form you want to normalize in. Should be one of
      #   the following: <tt>:c</tt>, <tt>:kc</tt>, <tt>:d</tt>, or <tt>:kd</tt>.
      #   Default is ActiveSupport::Multibyte::Unicode.default_normalization_form.
      def normalize(string, form = nil)
        raise NotImplementedError
      end

      def downcase(string)
        raise NotImplementedError
      end

      def upcase(string)
        raise NotImplementedError
      end

      def swapcase(string)
        raise NotImplementedError
      end

      # Rubinius' String#scrub, however, doesn't support ASCII-incompatible chars.
      if !defined?(Rubinius)
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
          out = "".force_encoding(Encoding::UTF_16LE)

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

      private

        def recode_windows1252_chars(string)
          string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
        end
    end
  end
end

ActiveSupport::Multibyte::Unicode.backend = :non_native
