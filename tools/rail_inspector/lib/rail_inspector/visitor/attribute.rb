# frozen_string_literal: true

require "prism"

module RailInspector
  module Visitor
    class Attribute < Prism::Visitor
      attr_reader :attribute_map

      def initialize
        @attribute_map = {}
        @namespace_stack = []
      end

      def with_namespace(node)
        @namespace_stack << node.constant_path.name
        visit_child_nodes(node)
        @namespace_stack.pop
      end

      alias visit_class_node with_namespace
      alias visit_module_node with_namespace

      def visit_call_node(node)
        attr_access = node.name
        return unless ATTRIBUTE_METHODS.include?(attr_access)

        full_namespace = @namespace_stack.join("::")

        @attribute_map[full_namespace] ||= {}
        @attribute_map[full_namespace][attr_access] ||= Set.new

        attributes = node.arguments.arguments.map { |p| p.value }

        @attribute_map[full_namespace][attr_access].merge(attributes)
      end

      private
        ATTRIBUTE_METHODS = %i[attr_accessor attr_reader attr_writer]
    end
  end
end
