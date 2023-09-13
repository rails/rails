# frozen_string_literal: true

require "set"
require "syntax_tree"

module RailInspector
  module Visitor
    class Attribute < SyntaxTree::Visitor
      attr_reader :attribute_map

      def initialize
        @attribute_map = {}
        @namespace_stack = []
      end

      def with_namespace(node)
        @namespace_stack << node.constant.constant.value
        visit_child_nodes(node)
        @namespace_stack.pop
      end

      visit_method alias_method :visit_module, :with_namespace

      visit_method alias_method :visit_class, :with_namespace

      visit_method def visit_command(node)
        attr_access = node.message.value
        return unless ATTRIBUTE_METHODS.include?(attr_access)

        full_namespace = @namespace_stack.join("::")

        @attribute_map[full_namespace] ||= {}
        @attribute_map[full_namespace][attr_access] ||= Set.new

        attributes = node.arguments.parts.map { |p| p.value.value }

        @attribute_map[full_namespace][attr_access].merge(attributes)
      end

      private
        ATTRIBUTE_METHODS = %w[attr_accessor attr_reader attr_writer]
    end
  end
end
