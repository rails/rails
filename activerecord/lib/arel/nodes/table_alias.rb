# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class TableAlias < Arel::Nodes::Binary
      alias :name :right
      alias :relation :left
      alias :table_alias :name

      def [](name)
        relation.is_a?(Table) ? relation[name, self] : Attribute.new(self, name)
      end

      def table_name
        relation.respond_to?(:name) ? relation.name : name
      end

      def type_cast_for_database(attr_name, value)
        relation.type_cast_for_database(attr_name, value)
      end

      def type_for_attribute(name)
        relation.type_for_attribute(name)
      end

      def able_to_type_cast?
        relation.respond_to?(:able_to_type_cast?) && relation.able_to_type_cast?
      end
    end
  end
end
