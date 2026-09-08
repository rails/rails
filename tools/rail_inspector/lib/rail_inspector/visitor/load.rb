# frozen_string_literal: true

require "prism"

module RailInspector
  module Visitor
    class Load < Prism::Visitor
      def initialize(&block)
        @current_loads = block
        @namespace_stack = []
      end

      def visit_module_node(node)
        case node.constant_path
        in Prism::ConstantReadNode[name:]
          @namespace_stack << name
        in Prism::ConstantPathNode
          @namespace_stack << node.constant_path.full_name
        end

        super

        @namespace_stack.pop
      end
      alias visit_class_node visit_module_node

      def visit_call_node(node)
        case node.name
        when :require
          case node.arguments.arguments[0]
          in Prism::StringNode[unescaped:]
            @current_loads.call[:requires] << unescaped
          else
            # dynamic require, like "active_support/cache/#{store}"
          end
        when :autoload
          case node.arguments.arguments
          in [Prism::SymbolNode[unescaped:]]
            namespaced_const = @namespace_stack.join("::")
            namespaced_const << "::" << unescaped

            @current_loads.call[:autoloads] << namespaced_const.underscore
          in [Prism::SymbolNode, Prism::StringNode[unescaped:]]
            @current_loads.call[:autoloads] << unescaped
          end
        end
      end
    end
  end
end
