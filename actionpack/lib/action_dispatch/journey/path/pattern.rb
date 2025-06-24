# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Journey # :nodoc:
    module Path # :nodoc:
      class Pattern # :nodoc:
        attr_reader :ast, :names, :requirements, :anchored, :spec

        def initialize(ast, requirements, separators, anchored)
          @ast          = ast
          @spec         = ast.root
          @requirements = requirements
          @separators   = separators
          @anchored     = anchored

          @names          = ast.names
          @optional_names = nil
          @required_names = nil
          @re             = nil
          @offsets        = nil
        end

        def build_formatter
          Visitors::FormatBuilder.new.accept(spec)
        end

        def eager_load!
          required_names
          offsets
          to_regexp
          @ast = nil
        end

        def requirements_anchored?
          # each required param must not be surrounded by a literal, otherwise it isn't
          # simple to chunk-match the url piecemeal
          terminals = ast.terminals

          terminals.each_with_index { |s, index|
            next if index < 1
            next if s.type == :DOT || s.type == :SLASH

            back = terminals[index - 1]
            fwd = terminals[index + 1]

            # we also don't support this yet, constraints must be regexps
            return false if s.symbol? && s.regexp.is_a?(Array)

            return false if back.literal?
            return false if !fwd.nil? && fwd.literal?
          }

          true
        end

        def required_names
          @required_names ||= names - optional_names
        end

        def optional_names
          @optional_names ||= spec.find_all(&:group?).flat_map { |group|
            group.find_all(&:symbol?)
          }.map(&:name).uniq
        end

        class AnchoredRegexp < Journey::Visitors::Visitor # :nodoc:
          def initialize(separator, matchers)
            @separator = separator
            @matchers  = matchers
            @separator_re = "([^#{separator}]+)"
            super()
          end

          def accept(node)
            %r{\A#{visit node}\Z}
          end

          def visit_CAT(node)
            "#{visit(node.left)}#{visit(node.right)}"
          end

          def visit_SYMBOL(node)
            node = node.to_sym

            return @separator_re unless @matchers.key?(node)

            re = @matchers[node]
            "(#{Regexp.union(re)})"
          end

          def visit_GROUP(node)
            "(?:#{visit node.left})?"
          end

          def visit_LITERAL(node)
            Regexp.escape(node.left)
          end
          alias :visit_DOT :visit_LITERAL

          def visit_SLASH(node)
            node.left
          end

          def visit_STAR(node)
            re = @matchers[node.left.to_sym]
            re ? "(#{re})" : "(.+)"
          end

          def visit_OR(node)
            children = node.children.map { |n| visit n }
            "(?:#{children.join(?|)})"
          end
        end

        class UnanchoredRegexp < AnchoredRegexp # :nodoc:
          def accept(node)
            path = visit node
            path == "/" ? %r{\A/} : %r{\A#{path}(?:\b|\Z|/)}
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
            Array.new(length - 1) { |i| self[i + 1] }
          end

          def named_captures
            @names.zip(captures).to_h
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

        def match(other)
          return unless match = to_regexp.match(other)
          MatchData.new(names, offsets, match)
        end
        alias :=~ :match

        def match?(other)
          to_regexp.match?(other)
        end

        def source
          to_regexp.source
        end

        def to_regexp
          @re ||= regexp_visitor.new(@separators, @requirements).accept spec
        end

        def requirements_for_missing_keys_check
          @requirements_for_missing_keys_check ||= requirements.transform_values do |regex|
            /\A#{regex}\Z/
          end
        end

        private
          def regexp_visitor
            @anchored ? AnchoredRegexp : UnanchoredRegexp
          end

          def offsets
            @offsets ||= begin
              offsets = [0]

              spec.find_all(&:symbol?).each do |node|
                node = node.to_sym

                if @requirements.key?(node)
                  re = /#{Regexp.union(@requirements[node])}|/
                  offsets.push((re.match("").length - 1) + offsets.last)
                else
                  offsets << offsets.last
                end
              end

              offsets
            end
          end
      end
    end
  end
end
