# frozen_string_literal: true

require "syntax_tree"

module RailInspector
  module Visitor
    class MultilineToString < SyntaxTree::Visitor
      attr_reader :to_s

      def initialize
        @to_s = +""
      end

      visit_methods do
        def visit_string_concat(node)
          @to_s << '"'
          super(node)
          @to_s << '"'
        end

        def visit_tstring_content(node)
          @to_s << node.value
        end
      end
    end
  end
end
