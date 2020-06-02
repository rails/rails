# frozen_string_literal: true

module ActiveRecord
  module TypeCaster
    class Map # :nodoc:
      def initialize(types)
        @types = types
      end

      def type_cast_for_database(attr_name, value)
        return value if value.is_a?(Arel::Nodes::BindParam)
        type = type_for_attribute(attr_name)
        type.serialize(value)
      end

      def type_for_attribute(name)
        types.type_for_attribute(name)
      end

      private
        attr_reader :types
    end
  end
end
