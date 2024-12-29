# frozen_string_literal: true

require "prism"

module RailInspector
  module Visitor
    class HashToString < Prism::Visitor
      attr_reader :to_s

      def initialize
        @to_s = +""
      end

      def visit_hash_node(node)
        @to_s << "{"

        if node.elements.length > 0
          visit(node.elements[0])

          if node.elements.length > 1
            node.elements[1..-1].each do |a|
              @to_s << ","
              visit(a)
            end
          end
          @to_s << " "
        end

        @to_s << "}"
      end

      def visit_assoc_node(node)
        @to_s << " "

        visit(node.key)

        case node.key
        in Prism::SymbolNode
          @to_s << ": "
        in Prism::StringNode
          @to_s << " => "
        end

        case node.value
        when Prism::SymbolNode
          @to_s << ":"
        end

        visit(node.value)
      end

      def visit_integer_node(node)
        @to_s << node.value.to_s
      end

      def visit_string_node(node)
        @to_s << '"'
        @to_s << node.unescaped
        @to_s << '"'
      end

      def visit_symbol_node(node)
        @to_s << node.unescaped
      end

      def visit_true_node(node)
        @to_s << "true"
      end

      def visit_false_node(node)
        @to_s << "false"
      end
    end
  end
end
