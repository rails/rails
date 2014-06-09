module ActiveRecord
  module Type
    class Serialized < SimpleDelegator # :nodoc:
      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def type_cast_from_database(value)
        if is_default_value?(value)
          value
        else
          coder.load(super)
        end
      end

      def type_cast_from_user(value)
        type_cast_from_database(type_cast_for_database(value))
      end

      def type_cast_for_database(value)
        return if value.nil?
        unless is_default_value?(value)
          super coder.dump(value)
        end
      end

      def serialized?
        true
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      private

      def is_default_value?(value)
        value == coder.load(nil)
      end
    end
  end
end
