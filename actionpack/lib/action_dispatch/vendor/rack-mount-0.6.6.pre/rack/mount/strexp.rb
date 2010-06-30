require 'rack/mount/strexp/parser'

module Rack::Mount
  class Strexp
    class << self
      # Parses segmented string expression and converts it into a Regexp
      #
      #   Strexp.compile('foo')
      #     # => %r{\Afoo\Z}
      #
      #   Strexp.compile('foo/:bar', {}, ['/'])
      #     # => %r{\Afoo/(?<bar>[^/]+)\Z}
      #
      #   Strexp.compile(':foo.example.com')
      #     # => %r{\A(?<foo>.+)\.example\.com\Z}
      #
      #   Strexp.compile('foo/:bar', {:bar => /[a-z]+/}, ['/'])
      #     # => %r{\Afoo/(?<bar>[a-z]+)\Z}
      #
      #   Strexp.compile('foo(.:extension)')
      #     # => %r{\Afoo(\.(?<extension>.+))?\Z}
      #
      #   Strexp.compile('src/*files')
      #     # => %r{\Asrc/(?<files>.+)\Z}
      def compile(str, requirements = {}, separators = [], anchor = true)
        return Regexp.compile(str) if str.is_a?(Regexp)

        requirements = requirements ? requirements.dup : {}
        normalize_requirements!(requirements, separators)

        parser = StrexpParser.new
        parser.anchor = anchor
        parser.requirements = requirements

        begin
          re = parser.scan_str(str)
        rescue Racc::ParseError => e
          raise RegexpError, e.message
        end

        Regexp.compile(re)
      end
      alias_method :new, :compile

      private
        def normalize_requirements!(requirements, separators)
          requirements.each do |key, value|
            if value.is_a?(Regexp)
              if regexp_has_modifiers?(value)
                requirements[key] = value
              else
                requirements[key] = value.source
              end
            else
              requirements[key] = Regexp.escape(value)
            end
          end
          requirements.default ||= separators.any? ?
            "[^#{separators.join}]+" : '.+'
          requirements
        end

        def regexp_has_modifiers?(regexp)
          regexp.options & (Regexp::IGNORECASE | Regexp::EXTENDED) != 0
        end
    end
  end
end
