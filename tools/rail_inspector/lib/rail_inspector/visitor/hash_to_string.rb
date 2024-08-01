# frozen_string_literal: true

require "syntax_tree"

module RailInspector
  module Visitor
    class HashToString < SyntaxTree::Visitor
      attr_reader :to_s

      def initialize
        @to_s = +""
      end

      visit_methods do
        def visit_assoc(node)
          @to_s << " "
          visit(node.key)

          case node.key
          when SyntaxTree::StringLiteral
            @to_s << " => "
          end

          visit(node.value)
        end

        def visit_hash(node)
          @to_s << "{"

          if node.assocs.length > 0
            visit(node.assocs[0])

            if node.assocs.length > 1
              node.assocs[1..-1].each do |a|
                @to_s << ","
                visit(a)
              end
            end
            @to_s << " "
          end

          @to_s << "}"
        end

        def visit_int(node)
          @to_s << node.value
        end

        def visit_kw(node)
          @to_s << node.value
        end

        def visit_label(node)
          @to_s << node.value
          @to_s << " "
        end

        def visit_tstring_content(node)
          @to_s << '"'
          @to_s << node.value
          @to_s << '"'
        end
      end
    end
  end
end
