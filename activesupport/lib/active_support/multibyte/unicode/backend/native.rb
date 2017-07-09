require "rbconfig"

module ActiveSupport
  module Multibyte
    module Unicode
      module Backend
        module Native # :nodoc:
          # The Unicode version that is supported by the ruby implementation
          UNICODE_VERSION = RbConfig::CONFIG["UNICODE_VERSION"]

          def in_char_class?(*)
            raise NotImplementedError
          end

          def unpack_graphemes(string)
            string.scan(/\X/).map(&:codepoints)
          end

          def pack_graphemes(unpacked)
            unpacked.flatten.pack("U*")
          end

          def reorder_characters(*)
            raise NotImplementedError
          end

          def decompose(type, codepoints)
            if type == :compatibility
              codepoints.pack("U*").unicode_normalize(:nfkd).codepoints
            else
              codepoints.pack("U*").unicode_normalize(:nfd).codepoints
            end
          end

          def compose(codepoints)
            codepoints.pack("U*").unicode_normalize(:nfc).codepoints
          end

          def normalize(string, form = nil)
            form ||= @default_normalization_form
            # See http://www.unicode.org/reports/tr15, Table 1
            case form
            when :d
              string.unicode_normalize(:nfd)
            when :c
              string.unicode_normalize(:nfc)
            when :kd
              string.unicode_normalize(:nfkd)
            when :kc
              string.unicode_normalize(:nfkc)
              else
              raise ArgumentError, "#{form} is not a valid normalization variant", caller
            end
          end

          def downcase(string)
            string.downcase
          end

          def upcase(string)
            string.upcase
          end

          def swapcase(string)
            string.swapcase
          end
        end
      end
    end
  end
end
