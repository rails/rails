module ActionDispatch
  # :stopdoc:
  module Journey
    class Format
      ESCAPE_PATH    = ->(value) { Router::Utils.escape_path(value) }
      ESCAPE_SEGMENT = ->(value) { Router::Utils.escape_segment(value) }

      Parameter = Struct.new(:name, :escaper) do
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

        parts.each_with_index do |object, i|
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
          return "".freeze unless value
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

          def visit(node)
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

      class FunctionalVisitor # :nodoc:
        DISPATCH_CACHE = {}

        def accept(node, seed)
          visit(node, seed)
        end

        def visit(node, seed)
          send(DISPATCH_CACHE[node.type], node, seed)
        end

        def binary(node, seed)
          visit(node.right, visit(node.left, seed))
        end
        def visit_CAT(n, seed); binary(n, seed); end

        def nary(node, seed)
          node.children.inject(seed) { |s, c| visit(c, s) }
        end
        def visit_OR(n, seed); nary(n, seed); end

        def unary(node, seed)
          visit(node.left, seed)
        end
        def visit_GROUP(n, seed); unary(n, seed); end
        def visit_STAR(n, seed); unary(n, seed); end

        def terminal(node, seed);   seed; end
        def visit_LITERAL(n, seed); terminal(n, seed); end
        def visit_SYMBOL(n, seed);  terminal(n, seed); end
        def visit_SLASH(n, seed);   terminal(n, seed); end
        def visit_DOT(n, seed);     terminal(n, seed); end

        instance_methods(false).each do |pim|
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
      class Each < FunctionalVisitor # :nodoc:
        def visit(node, block)
          block.call(node)
          super
        end

        INSTANCE = new
      end

      class String < FunctionalVisitor # :nodoc:
        private

          def binary(node, seed)
            visit(node.right, visit(node.left, seed))
          end

          def nary(node, seed)
            last_child = node.children.last
            node.children.inject(seed) { |s, c|
              string = visit(c, s)
              string << "|".freeze unless last_child == c
              string
            }
          end

          def terminal(node, seed)
            seed + node.left
          end

          def visit_GROUP(node, seed)
            visit(node.left, seed << "(".freeze) << ")".freeze
          end

          INSTANCE = new
      end

      class Dot < FunctionalVisitor # :nodoc:
        def initialize
          @nodes = []
          @edges = []
        end

        def accept(node, seed = [[], []])
          super
          nodes, edges = seed
          <<-eodot
  digraph parse_tree {
    size="8,5"
    node [shape = none];
    edge [dir = none];
    #{nodes.join "\n"}
    #{edges.join("\n")}
  }
          eodot
        end

        private

          def binary(node, seed)
            seed.last.concat node.children.map { |c|
              "#{node.object_id} -> #{c.object_id};"
            }
            super
          end

          def nary(node, seed)
            seed.last.concat node.children.map { |c|
              "#{node.object_id} -> #{c.object_id};"
            }
            super
          end

          def unary(node, seed)
            seed.last << "#{node.object_id} -> #{node.left.object_id};"
            super
          end

          def visit_GROUP(node, seed)
            seed.first << "#{node.object_id} [label=\"()\"];"
            super
          end

          def visit_CAT(node, seed)
            seed.first << "#{node.object_id} [label=\"○\"];"
            super
          end

          def visit_STAR(node, seed)
            seed.first << "#{node.object_id} [label=\"*\"];"
            super
          end

          def visit_OR(node, seed)
            seed.first << "#{node.object_id} [label=\"|\"];"
            super
          end

          def terminal(node, seed)
            value = node.left

            seed.first << "#{node.object_id} [label=\"#{value}\"];"
            seed
          end
          INSTANCE = new
      end
    end
  end
  # :startdoc:
end
