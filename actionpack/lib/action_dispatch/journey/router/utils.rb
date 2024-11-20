# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Utils # :nodoc:
        # Normalizes URI path.
        #
        # Strips off trailing slash and ensures there is a leading slash. Also converts
        # downcase URL encoded string to uppercase.
        #
        #     normalize_path("/foo")  # => "/foo"
        #     normalize_path("/foo/") # => "/foo"
        #     normalize_path("foo")   # => "/foo"
        #     normalize_path("")      # => "/"
        #     normalize_path("/%ab")  # => "/%AB"
        def self.normalize_path(path)
          path ||= ""
          encoding = path.encoding
          path = +"/#{path}"
          path.squeeze!("/")

          unless path == "/"
            path.delete_suffix!("/")
            path.gsub!(/(%[a-f0-9]{2})/) { $1.upcase }
          end

          path.force_encoding(encoding)
        end

        # URI path and fragment escaping https://tools.ietf.org/html/rfc3986
        class UriEncoder # :nodoc:
          ENCODE   = "%%%02X"
          US_ASCII = Encoding::US_ASCII
          UTF_8    = Encoding::UTF_8
          EMPTY    = (+"").force_encoding(US_ASCII).freeze
          DEC2HEX  = (0..255).map { |i| (ENCODE % i).force_encoding(US_ASCII) }

          ALPHA = "a-zA-Z"
          DIGIT = "0-9"
          UNRESERVED = "#{ALPHA}#{DIGIT}\\-\\._~"
          SUB_DELIMS = "!\\$&'\\(\\)\\*\\+,;="

          ESCAPED  = /%[a-zA-Z0-9]{2}/

          FRAGMENT = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/?]/
          SEGMENT  = /[^#{UNRESERVED}#{SUB_DELIMS}:@]/
          PATH     = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/]/

          def escape_fragment(fragment)
            escape(fragment, FRAGMENT)
          end

          def escape_path(path)
            escape(path, PATH)
          end

          def escape_segment(segment)
            escape(segment, SEGMENT)
          end

          def unescape_uri(uri)
            encoding = uri.encoding == US_ASCII ? UTF_8 : uri.encoding
            uri.gsub(ESCAPED) { |match| [match[1, 2].hex].pack("C") }.force_encoding(encoding)
          end

          private
            def escape(component, pattern)
              component.gsub(pattern) { |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
            end

            def percent_encode(unsafe)
              safe = EMPTY.dup
              unsafe.each_byte { |b| safe << DEC2HEX[b] }
              safe
            end
        end

        ENCODER = UriEncoder.new

        def self.escape_path(path)
          ENCODER.escape_path(path.to_s)
        end

        def self.escape_segment(segment)
          ENCODER.escape_segment(segment.to_s)
        end

        def self.escape_fragment(fragment)
          ENCODER.escape_fragment(fragment.to_s)
        end

        # Replaces any escaped sequences with their unescaped representations.
        #
        #     uri = "/topics?title=Ruby%20on%20Rails"
        #     unescape_uri(uri)  #=> "/topics?title=Ruby on Rails"
        def self.unescape_uri(uri)
          ENCODER.unescape_uri(uri)
        end
      end
    end
  end
end
