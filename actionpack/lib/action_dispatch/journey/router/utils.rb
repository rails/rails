module ActionDispatch
  module Journey # :nodoc:
    class Router # :nodoc:
      class Utils # :nodoc:
        # Normalizes URI path.
        #
        # Strips off trailing slash and ensures there is a leading slash.
        # Also converts downcase url encoded string to uppercase.
        #
        #   normalize_path("/foo")  # => "/foo"
        #   normalize_path("/foo/") # => "/foo"
        #   normalize_path("foo")   # => "/foo"
        #   normalize_path("")      # => "/"
        #   normalize_path("/%ab")  # => "/%AB"
        def self.normalize_path(path)
          path = "/#{path}"
          path.squeeze!('/'.freeze)
          path.sub!(%r{/+\Z}, ''.freeze)
          path.gsub!(/(%[a-f0-9]{2})/) { $1.upcase }
          path = '/' if path == ''.freeze
          path
        end

        # URI path and fragment escaping
        # http://tools.ietf.org/html/rfc3986
        class UriEncoder # :nodoc:
          ENCODE   = "%%%02X".freeze
          US_ASCII = Encoding::US_ASCII
          UTF_8    = Encoding::UTF_8
          EMPTY    = "".force_encoding(US_ASCII).freeze
          DEC2HEX  = (0..255).to_a.map{ |i| ENCODE % i }.map{ |s| s.force_encoding(US_ASCII) }

          ALPHA = "a-zA-Z".freeze
          DIGIT = "0-9".freeze
          UNRESERVED = "#{ALPHA}#{DIGIT}\\-\\._~".freeze
          SUB_DELIMS = "!\\$&'\\(\\)\\*\\+,;=".freeze

          ESCAPED  = /%[a-zA-Z0-9]{2}/.freeze

          FRAGMENT = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/\?]/.freeze
          SEGMENT  = /[^#{UNRESERVED}#{SUB_DELIMS}:@]/.freeze
          PATH     = /[^#{UNRESERVED}#{SUB_DELIMS}:@\/]/.freeze

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
            uri.gsub(ESCAPED) { |match| [match[1, 2].hex].pack('C') }.force_encoding(encoding)
          end

          protected
            def escape(component, pattern)
              component.gsub(pattern){ |unsafe| percent_encode(unsafe) }.force_encoding(US_ASCII)
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

        def self.unescape_uri(uri)
          ENCODER.unescape_uri(uri)
        end
      end
    end
  end
end
