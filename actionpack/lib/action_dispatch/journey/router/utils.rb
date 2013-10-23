require 'uri'

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
          path.squeeze!('/')
          path.sub!(%r{/+\Z}, '')
          path.gsub!(/(%[a-f0-9]{2})/) { $1.upcase }
          path = '/' if path == ''
          path
        end

        # URI path and fragment escaping
        # http://tools.ietf.org/html/rfc3986
        module UriEscape # :nodoc:
          # Symbol captures can generate multiple path segments, so include /.
          reserved_segment  = '/'
          reserved_fragment = '/?'
          reserved_pchar    = ':@&=+$,;%'

          safe_pchar    = "#{URI::REGEXP::PATTERN::UNRESERVED}#{reserved_pchar}"
          safe_segment  = "#{safe_pchar}#{reserved_segment}"
          safe_fragment = "#{safe_pchar}#{reserved_fragment}"
          UNSAFE_SEGMENT  = Regexp.new("[^#{safe_segment}]", false).freeze
          UNSAFE_FRAGMENT = Regexp.new("[^#{safe_fragment}]", false).freeze
        end

        Parser = URI.const_defined?(:Parser) ? URI::Parser.new : URI

        def self.escape_path(path)
          Parser.escape(path.to_s, UriEscape::UNSAFE_SEGMENT)
        end

        def self.escape_fragment(fragment)
          Parser.escape(fragment.to_s, UriEscape::UNSAFE_FRAGMENT)
        end

        def self.unescape_uri(uri)
          Parser.unescape(uri)
        end
      end
    end
  end
end
