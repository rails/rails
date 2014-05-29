module ActiveRecord
  module Type
    class Serialized < SimpleDelegator # :nodoc:
      attr_reader :subtype

      def initialize(subtype)
        @subtype = subtype
        super
      end

      def type_cast(value)
        if value.respond_to?(:unserialized_value)
          value.unserialized_value(super(value.value))
        else
          super
        end
      end

      def serialized?
        true
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end
    end
  end
end
