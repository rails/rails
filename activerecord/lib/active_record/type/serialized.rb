module ActiveRecord
  module Type
    class Serialized < DelegateClass(Type::Value) # :nodoc:
      include Mutable
      include Decorator

      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def type_cast_from_database(value)
        coder.load(super)
      end

      def type_cast_for_database(value)
        super coder.dump(value)
      end

      def changed_in_place?(raw_old_value, value)
        subtype.changed_in_place?(raw_old_value, coder.dump(value))
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      def init_with(coder)
        @coder = coder['coder']
        super
      end

      def encode_with(coder)
        coder['coder'] = @coder
        super
      end
    end
  end
end
