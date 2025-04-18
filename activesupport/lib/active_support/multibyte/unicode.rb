# frozen_string_literal: true

module ActiveSupport
  module Multibyte
    module Unicode
      extend self

      # The Unicode version that is supported by the implementation
      UNICODE_VERSION = RbConfig::CONFIG["UNICODE_VERSION"]

      # Decompose composed characters to the decomposed form.
      def decompose(type, codepoints)
        if type == :compatibility
          codepoints.pack("U*").unicode_normalize(:nfkd).codepoints
        else
          codepoints.pack("U*").unicode_normalize(:nfd).codepoints
        end
      end

      # Compose decomposed characters to the composed form.
      def compose(codepoints)
        codepoints.pack("U*").unicode_normalize(:nfc).codepoints
      end

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

      private
        def recode_windows1252_chars(string)
          string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
        end
    end
  end
end
