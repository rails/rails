# frozen_string_literal: true

require "action_dispatch/journey/scanner"
require "action_dispatch/journey/nodes/node"

module ActionDispatch
  module Journey # :nodoc:
    class Parser # :nodoc:
      include Journey::Nodes

      def self.parse(string)
        new.parse string
      end

      def initialize
        @scanner = Scanner.new
        @next_token = nil
      end

      def parse(string)
        @scanner.scan_setup(string)
        advance_token
        do_parse
      end

      private
        def advance_token
          @next_token = @scanner.next_token
        end

        def do_parse
          parse_expressions
        end

        def parse_expressions
          node = parse_expression

          while @next_token
            case @next_token
            when :RPAREN
              break
            when :OR
              node = parse_or(node)
            else
              node = Cat.new(node, parse_expressions)
            end
          end

          node
        end

        def parse_or(lhs)
          advance_token
          node = parse_expression
          Or.new([lhs, node])
        end

        def parse_expression
          if @next_token == :STAR
            parse_star
          elsif @next_token == :LPAREN
            parse_group
          else
            parse_terminal
          end
        end

        def parse_star
          node = Star.new(Symbol.new(@scanner.last_string, Symbol::GREEDY_EXP))
          advance_token
          node
        end

        def parse_group
          advance_token
          node = parse_expressions
          if @next_token == :RPAREN
            node = Group.new(node)
            advance_token
            node
          else
            raise ArgumentError, "missing right parenthesis."
          end
        end

        def parse_terminal
          node = case @next_token
          when :SYMBOL
            Symbol.new(@scanner.last_string)
          when :LITERAL
            Literal.new(@scanner.last_literal)
          when :SLASH
            Slash.new("/")
          when :DOT
            Dot.new(".")
          end

          advance_token
          node
        end
    end
  end
end
