module ActiveRecord
  module Type
    class Serialized < DelegateClass(Type::Value) # :nodoc:
      include Helpers::Mutable

      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def deserialize(value)
        coder.load(value)
      end

      def serialize(value)
        coder.dump(value)
      end

      def inspect
        Kernel.instance_method(:inspect).bind(self).call
      end

      def changed_in_place?(raw_old_value, value)
        return false if value.nil?
        raw_new_value = serialize(value)
        raw_old_value.nil? != raw_new_value.nil? ||
          subtype.changed_in_place?(raw_old_value, raw_new_value)
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end
    end
  end
end
