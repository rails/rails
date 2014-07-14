# encoding: utf-8

module ActionDispatch
  module Journey # :nodoc:
    class Format
      ESCAPE_PATH    = ->(value) { Router::Utils.escape_path(value) }
      ESCAPE_SEGMENT = ->(value) { Router::Utils.escape_segment(value) }

      class Parameter < Struct.new(:name, :escaper)
        def escape(value); escaper.call value; end
      end

      def self.required_path(symbol)
        Parameter.new symbol, ESCAPE_PATH
      end

      def self.required_segment(symbol)
        Parameter.new symbol, ESCAPE_SEGMENT
      end

      def initialize(parts)
        @parts      = parts
        @children   = []
        @parameters = []

        parts.each_with_index do |object,i|
          case object
          when Journey::Format
            @children << i
          when Parameter
            @parameters << i
          end
        end
      end

      def evaluate(hash)
        parts = @parts.dup

        @parameters.each do |index|
          param = parts[index]
          value = hash[param.name]
          return ''.freeze unless value
          parts[index] = param.escape value
        end

        @children.each { |index| parts[index] = parts[index].evaluate(hash) }

        parts.join
      end
    end

    module Visitors # :nodoc:
      class Visitor # :nodoc:
        DISPATCH_CACHE = {}

        def accept(node)
          visit(node)
        end

        private

          def visit node
            send(DISPATCH_CACHE[node.type], node)
          end

          def binary(node)
            visit(node.left)
            visit(node.right)
          end
          def visit_CAT(n); binary(n); end

          def nary(node)
            node.children.each { |c| visit(c) }
          end
          def visit_OR(n); nary(n); end

          def unary(node)
            visit(node.left)
          end
          def visit_GROUP(n); unary(n); end
          def visit_STAR(n); unary(n); end

          def terminal(node); end
          def visit_LITERAL(n); terminal(n); end
          def visit_SYMBOL(n);  terminal(n); end
          def visit_SLASH(n);   terminal(n); end
          def visit_DOT(n);     terminal(n); end

          private_instance_methods(false).each do |pim|
            next unless pim =~ /^visit_(.*)$/
            DISPATCH_CACHE[$1.to_sym] = pim
          end
      end

      class FormatBuilder < Visitor # :nodoc:
        def accept(node); Journey::Format.new(super); end
        def terminal(node); [node.left]; end

        def binary(node)
          visit(node.left) + visit(node.right)
        end

        def visit_GROUP(n); [Journey::Format.new(unary(n))]; end

        def visit_STAR(n)
          [Journey::Format.required_path(n.left.to_sym)]
        end

        def visit_SYMBOL(n)
          symbol = n.to_sym
          if symbol == :controller
            [Journey::Format.required_path(symbol)]
          else
            [Journey::Format.required_segment(symbol)]
          end
        end
      end

      # Loop through the requirements AST
      class Each < Visitor # :nodoc:
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def visit(node)
          block.call(node)
          super
        end
      end

      class String < Visitor # :nodoc:
        private

        def binary(node)
          [visit(node.left), visit(node.right)].join
        end

        def nary(node)
          node.children.map { |c| visit(c) }.join '|'
        end

        def terminal(node)
          node.left
        end

        def visit_GROUP(node)
          "(#{visit(node.left)})"
        end
      end

      class Dot < Visitor # :nodoc:
        def initialize
          @nodes = []
          @edges = []
        end

        def accept(node)
          super
          <<-eodot
  digraph parse_tree {
    size="8,5"
    node [shape = none];
    edge [dir = none];
    #{@nodes.join "\n"}
    #{@edges.join("\n")}
  }
          eodot
        end

        private

          def binary(node)
            node.children.each do |c|
              @edges << "#{node.object_id} -> #{c.object_id};"
            end
            super
          end

          def nary(node)
            node.children.each do |c|
              @edges << "#{node.object_id} -> #{c.object_id};"
            end
            super
          end

          def unary(node)
            @edges << "#{node.object_id} -> #{node.left.object_id};"
            super
          end

          def visit_GROUP(node)
            @nodes << "#{node.object_id} [label=\"()\"];"
            super
          end

          def visit_CAT(node)
            @nodes << "#{node.object_id} [label=\"○\"];"
            super
          end

          def visit_STAR(node)
            @nodes << "#{node.object_id} [label=\"*\"];"
            super
          end

          def visit_OR(node)
            @nodes << "#{node.object_id} [label=\"|\"];"
            super
          end

          def terminal(node)
            value = node.left

            @nodes << "#{node.object_id} [label=\"#{value}\"];"
          end
      end
    end
  end
end
