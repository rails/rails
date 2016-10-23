module ActiveRecord
  module Type
    class Serialized < DelegateClass(ActiveModel::Type::Value) # :nodoc:
      include ActiveModel::Type::Helpers::Mutable

      attr_reader :subtype, :coder

      def initialize(subtype, coder)
        @subtype = subtype
        @coder = coder
        super(subtype)
      end

      def deserialize(value)
        if default_value?(value)
          value
        else
          coder.load(super)
        end
      end

      def serialize(value)
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
        raw_new_value = encoded(value)
        raw_old_value.nil? != raw_new_value.nil? ||
          subtype.changed_in_place?(raw_old_value, raw_new_value)
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      def assert_valid_value(value)
        if coder.respond_to?(:assert_valid_value)
          coder.assert_valid_value(value)
        end
      end

      private

        def default_value?(value)
          value == coder.load(nil)
        end

        def encoded(value)
          unless default_value?(value)
            coder.dump(value)
          end
        end
    end
  end
end
