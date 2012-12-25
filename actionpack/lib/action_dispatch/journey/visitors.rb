# encoding: utf-8
module ActionDispatch
  module Journey # :nodoc:
    module Visitors # :nodoc:
      class Visitor # :nodoc:
        DISPATCH_CACHE = Hash.new { |h,k|
          h[k] = "visit_#{k}"
        }

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
          %w{ LITERAL SYMBOL SLASH DOT }.each do |t|
            class_eval %{ def visit_#{t}(n); terminal(n); end }, __FILE__, __LINE__
          end
      end

      # Loop through the requirements AST
      class Each < Visitor # :nodoc:
        attr_reader :block

        def initialize(block)
          @block = block
        end

        def visit(node)
          super
          block.call(node)
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

      # Used for formatting urls (url_for)
      class Formatter < Visitor # :nodoc:
        attr_reader :options, :consumed

        def initialize(options)
          @options  = options
          @consumed = {}
        end

        private

          def visit_GROUP(node)
            if consumed == options
              nil
            else
              route = visit(node.left)
              route.include?("\0") ? nil : route
            end
          end

          def terminal(node)
            node.left
          end

          def binary(node)
            [visit(node.left), visit(node.right)].join
          end

          def nary(node)
            node.children.map { |c| visit(c) }.join
          end

          def visit_SYMBOL(node)
            key = node.to_sym

            if value = options[key]
              consumed[key] = value
              Router::Utils.escape_path(value)
            else
              "\0"
            end
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
