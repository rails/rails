# frozen_string_literal: true

module ActiveSupport
  module Multibyte
    module Unicode
      extend self

      # A list of all available normalization forms.
      # See https://www.unicode.org/reports/tr15/tr15-29.html for more
      # information about normalization.
      NORMALIZATION_FORMS = [:c, :kc, :d, :kd]

      NORMALIZATION_FORM_ALIASES = { # :nodoc:
        c: :nfc,
        d: :nfd,
        kc: :nfkc,
        kd: :nfkd
      }

      # The Unicode version that is supported by the implementation
      UNICODE_VERSION = RbConfig::CONFIG['UNICODE_VERSION']

      # The default normalization used for operations that require
      # normalization. It can be set to any of the normalizations
      # in NORMALIZATION_FORMS.
      #
      #   ActiveSupport::Multibyte::Unicode.default_normalization_form = :c
      attr_accessor :default_normalization_form
      @default_normalization_form = :kc

      # Unpack the string at grapheme boundaries. Returns a list of character
      # lists.
      #
      #   Unicode.unpack_graphemes('क्षि') # => [[2325, 2381], [2359], [2367]]
      #   Unicode.unpack_graphemes('Café') # => [[67], [97], [102], [233]]
      def unpack_graphemes(string)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          ActiveSupport::Multibyte::Unicode#unpack_graphemes is deprecated and will be
          removed from Rails 6.1. Use string.scan(/\X/).map(&:codepoints) instead.
        MSG

        string.scan(/\X/).map(&:codepoints)
      end

      # Reverse operation of unpack_graphemes.
      #
      #   Unicode.pack_graphemes(Unicode.unpack_graphemes('क्षि')) # => 'क्षि'
      def pack_graphemes(unpacked)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          ActiveSupport::Multibyte::Unicode#pack_graphemes is deprecated and will be
          removed from Rails 6.1. Use array.flatten.pack("U*") instead.
        MSG

        unpacked.flatten.pack('U*')
      end

      # Decompose composed characters to the decomposed form.
      def decompose(type, codepoints)
        if type == :compatibility
          codepoints.pack('U*').unicode_normalize(:nfkd).codepoints
        else
          codepoints.pack('U*').unicode_normalize(:nfd).codepoints
        end
      end

      # Compose decomposed characters to the composed form.
      def compose(codepoints)
        codepoints.pack('U*').unicode_normalize(:nfc).codepoints
      end

      # Rubinius' String#scrub, however, doesn't support ASCII-incompatible chars.
      if !defined?(Rubinius)
        # Replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent
        # resulting in a valid UTF-8 string.
        #
        # Passing +true+ will forcibly tidy all bytes, assuming that the string's
        # encoding is entirely CP1252 or ISO-8859-1.
        def tidy_bytes(string, force = false)
          return string if string.empty? || string.ascii_only?
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
      #   Default is ActiveSupport::Multibyte::Unicode.default_normalization_form.
      def normalize(string, form = nil)
        form ||= @default_normalization_form

        # See https://www.unicode.org/reports/tr15, Table 1
        if alias_form = NORMALIZATION_FORM_ALIASES[form]
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            ActiveSupport::Multibyte::Unicode#normalize is deprecated and will be
            removed from Rails 6.1. Use String#unicode_normalize(:#{alias_form}) instead.
          MSG

          string.unicode_normalize(alias_form)
        else
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            ActiveSupport::Multibyte::Unicode#normalize is deprecated and will be
            removed from Rails 6.1. Use String#unicode_normalize instead.
          MSG

          raise ArgumentError, "#{form} is not a valid normalization variant", caller
        end
      end

      %w(downcase upcase swapcase).each do |method|
        define_method(method) do |string|
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
          ActiveSupport::Multibyte::Unicode##{method} is deprecated and
          will be removed from Rails 6.1. Use String methods directly.
          MSG

          string.send(method)
        end
      end

      private
        def recode_windows1252_chars(string)
          string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
        end
    end
  end
end
