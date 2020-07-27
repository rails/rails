# frozen_string_literal: true

require "action_dispatch/journey/visitors"

module ActionDispatch
  module Journey # :nodoc:
    class Ast # :nodoc:
      delegate :find_all, :left, :right, :to_s, :to_sym, :type, to: :tree
      attr_reader :names, :path_params, :tree, :wildcard_options
      alias :root :tree

      def initialize(tree, formatted)
        @tree = tree
        @path_params = []
        @names = []
        @symbols = []
        @glob = false
        @wildcard_options = {}
        @terminals = []

        visit_tree(formatted)
      end

      def requirements=(requirements)
        symbols.each do |node|
          re = requirements[node.to_sym]
          node.regexp = re if re
        end
      end

      def route=(route)
        terminals.each { |n| n.memo = route }
      end

      def default_regexp?
        symbols.all?(&:default_regexp?)
      end

      def glob?
        @glob
      end

      private
        attr_reader :symbols, :terminals

        def visit_tree(formatted)
          tree.each do |node|
            if node.symbol?
              path_params << node.to_sym
              names << node.name
              symbols << node
            elsif node.star?
              @glob = true

              if formatted != false
                # Add a constraint for wildcard route to make it non-greedy and
                # match the optional format part of the route by default.
                wildcard_options[node.name.to_sym] ||= /.+?/
              end
            elsif node.cat?
              alter_regex_for_custom_routes(node)
            end

            if node.terminal?
              terminals << node
            end
          end
        end

        # Find all the symbol nodes that are adjacent to literal nodes and alter
        # the regexp so that Journey will partition them into custom routes.
        def alter_regex_for_custom_routes(node)
          if node.left.literal? && node.right.symbol?
            symbol = node.right
          elsif node.left.literal? && node.right.cat? && node.right.left.symbol?
            symbol = node.right.left
          elsif node.left.symbol? && node.right.literal?
            symbol = node.left
          elsif node.left.symbol? && node.right.cat? && node.right.left.literal?
            symbol = node.left
          end

          if symbol
            symbol.regexp = /(?:#{Regexp.union(symbol.regexp, '-')})+/
          end
        end
    end

    module Nodes # :nodoc:
      class Node # :nodoc:
        include Enumerable

        attr_accessor :left, :memo

        def initialize(left)
          @left = left
          @memo = nil
        end

        def each(&block)
          Visitors::Each::INSTANCE.accept(self, block)
        end

        def to_s
          Visitors::String::INSTANCE.accept(self, "")
        end

        def to_dot
          Visitors::Dot::INSTANCE.accept(self)
        end

        def to_sym
          name.to_sym
        end

        def name
          -left.tr("*:", "")
        end

        def type
          raise NotImplementedError
        end

        def symbol?; false; end
        def literal?; false; end
        def terminal?; false; end
        def star?; false; end
        def cat?; false; end
        def group?; false; end
      end

      class Terminal < Node # :nodoc:
        alias :symbol :left
        def terminal?; true; end
      end

      class Literal < Terminal # :nodoc:
        def literal?; true; end
        def type; :LITERAL; end
      end

      class Dummy < Literal # :nodoc:
        def initialize(x = Object.new)
          super
        end

        def literal?; false; end
      end

      class Slash < Terminal # :nodoc:
        def type; :SLASH; end
      end

      class Dot < Terminal # :nodoc:
        def type; :DOT; end
      end

      class Symbol < Terminal # :nodoc:
        attr_accessor :regexp
        alias :symbol :regexp
        attr_reader :name

        DEFAULT_EXP = /[^\.\/\?]+/
        GREEDY_EXP = /(.+)/
        def initialize(left, regexp = DEFAULT_EXP)
          super(left)
          @regexp = regexp
          @name = -left.tr("*:", "")
        end

        def default_regexp?
          regexp == DEFAULT_EXP
        end

        def type; :SYMBOL; end
        def symbol?; true; end
      end

      class Unary < Node # :nodoc:
        def children; [left] end
      end

      class Group < Unary # :nodoc:
        def type; :GROUP; end
        def group?; true; end
      end

      class Star < Unary # :nodoc:
        def star?; true; end
        def type; :STAR; end

        def name
          left.name.tr "*:", ""
        end
      end

      class Binary < Node # :nodoc:
        attr_accessor :right

        def initialize(left, right)
          super(left)
          @right = right
        end

        def children; [left, right] end
      end

      class Cat < Binary # :nodoc:
        def cat?; true; end
        def type; :CAT; end
      end

      class Or < Node # :nodoc:
        attr_reader :children

        def initialize(children)
          @children = children
        end

        def type; :OR; end
      end
    end
  end
end
