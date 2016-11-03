require "active_record/attribute"

module ActiveRecord
  class Relation
    class QueryAttribute < Attribute # :nodoc:
      def type_cast(value)
        value
      end

      def value_for_database
        @value_for_database ||= super
      end

      def with_cast_value(value)
        QueryAttribute.new(name, value, type)
      end
    end
  end
end
