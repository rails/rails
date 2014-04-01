module ActionDispatch
  module Routing
    class Path
      attr_reader :requirements, :anchored, :string

      def initialize(strexp)
        @anchored = true
        case strexp
        when String
          @string       = strexp
          @requirements = {}
          @separators   = "/.?"
        when Routing::Router::Strexp
          @string       = strexp.path
          @requirements = strexp.requirements
          @separators   = strexp.separators.join
          @anchored     = strexp.anchor
        else
          raise ArgumentError, "Bad expression: #{strexp}"
        end

        @names, @optional_names, @required_names, @re, @offsets = nil, nil, nil, nil ,nil
      end

      def names
        @names ||= @string.scan(/(?<=[\*:])\w+/)
      end

      def required_names
        @required_names ||= names - optional_names
      end

      def optional_names
        @optional_names ||= @string.scan(/\(\/?\w*\/?[:\.]+(\w+)/).flatten.sort
      end

      class RegexpOffsets # :nodoc:
        class << self
          def build(path)
            matchers = path.requirements

            path.names.inject([0]) do |count, name|
              name = name.to_sym

              if matchers.key?(name)
                re = /#{matchers[name]}|/
                count.push((re.match('').length - 1) + (count.last || 0))
              else
                count << (count.last || 0)
              end
            end
          end
        end
      end

      class MatchData # :nodoc:
        attr_reader :names

        def initialize(names, offsets, match)
          @names   = names
          @offsets = offsets
          @match   = match
        end

        def captures
          (length - 1).times.map { |i| self[i + 1] }
        end

        def [](x)
          idx = @offsets[x - 1] + x
          @match[idx]
        end

        def length
          @offsets.length
        end

        def post_match
          @match.post_match
        end

        def to_s
          @match.to_s
        end
      end

      class RegexpBuilder # :nodoc:
        SEPARATORS = { '(' => '(?:', ')' => ')?', '.'  => '\.' }.freeze

        class << self
          def build(path)
            pairs = path.names.map do |name|
              value = path.requirements[name.to_sym]
              match = path.string.match(/([:\*])#{name}/)

              case match[1]
              when ':'
                value = value ? "(#{value})" : '([^/.?]+)'
              when '*'
                value = value ? "(#{value})" : '(.+)'
              end

              [match[0], value]
            end

            hash = Hash[pairs].merge(SEPARATORS)
            re   = %r{(#{ hash.keys.map { |k| Regexp.escape k }.join('|') })}

            string = path.string.gsub re, hash
            string = '\A' + string
            string << '\Z' if path.anchored

            Regexp.compile string
          end
        end
      end

      def match(other)
        return unless match = to_regexp.match(other)
        MatchData.new(names, offsets, match)
      end
      alias :=~ :match

      def source
        to_regexp.source
      end

      def to_regexp
        @re ||= RegexpBuilder.build(self)
      end

      private

        def offsets
          return @offsets if @offsets
          @offsets = RegexpOffsets.build(self)
        end
    end
  end
end
