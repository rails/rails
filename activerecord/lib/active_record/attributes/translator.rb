module ActiveRecord
  module Attributes
    class Translator # :nodoc:
      def initialize(attributes, column_types)
        @attributes   = attributes
        @column_types = column_types
      end

      def cast_attribute(attr_name, method)
        v = @attributes.fetch(attr_name) { yield }
        v && send(method, attr_name, v)
      end

      def cast_serialized(attr_name, value)
        value.unserialized_value
      end

      def cast_tz_conversion(attr_name, value)
        value = cast_column(attr_name, value)
        value.acts_like?(:time) ? value.in_time_zone : value
      end

      def cast_column(attr_name, value)
        @column_types[attr_name].type_cast value
      end
    end
  end
end
