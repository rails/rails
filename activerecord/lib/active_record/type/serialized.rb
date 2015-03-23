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
        if default_value?(value)
          value
        else
          coder.load(super)
        end
      end

      def type_cast_for_database(value)
        return if value.nil?
        unless default_value?(value)
          super coder.dump(value)
        end
      end

      def inspect
        Kernel.instance_method(:inspect).bind(self).call
      end

      def changed_in_place?(raw_old_value, value)
        return false if value.nil?
        raw_new_value = type_cast_for_database(value)
        raw_old_value.nil? != raw_new_value.nil? ||
          subtype.changed_in_place?(raw_old_value, raw_new_value)
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

      private

      def default_value?(value)
        value == coder.load(nil)
      end
    end
  end
end
