# frozen_string_literal: true

module ActiveRecord
  module TypeCaster
    class Connection # :nodoc:
      def initialize(klass)
        @klass = klass
      end

      def type_cast_for_database(attr_name, value)
        type = type_for_attribute(attr_name)
        type.serialize(value)
      end

      def type_for_attribute(attr_name)
        @klass.type_for_attribute(attr_name) || Type.default_value
      end
    end
  end
end
