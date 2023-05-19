# frozen_string_literal: true

module ActiveRecord
  module Type
    class Serialized < DelegateClass(ActiveModel::Type::Value) # :nodoc:
      undef to_yaml if method_defined?(:to_yaml)

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
        Kernel.instance_method(:inspect).bind_call(self)
      end

      def changed_in_place?(raw_old_value, value)
        return false if value.nil?
        raw_new_value = encoded(value)
        return true if raw_old_value.nil? != raw_new_value.nil?
        if raw_new_value.present? && raw_new_value.is_a?(::String) && raw_new_value.encoding == Encoding::BINARY && raw_old_value.is_a?(ActiveModel::Type::Binary::Data)
          raw_old_value_s = raw_old_value.to_s.frozen? ? raw_old_value.to_s.dup : raw_old_value.to_s
          # This line will change the string that is used inside of raw_old_value.
          raw_old_value_s.force_encoding(Encoding::BINARY) if raw_old_value_s.encoding == Encoding::UTF_8
          raw_old_value = ActiveModel::Type::Binary::Data.new(raw_old_value_s)
        end
        subtype.changed_in_place?(raw_old_value, raw_new_value)
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      def assert_valid_value(value)
        if coder.respond_to?(:assert_valid_value)
          coder.assert_valid_value(value, action: "serialize")
        end
      end

      def force_equality?(value)
        coder.respond_to?(:object_class) && value.is_a?(coder.object_class)
      end

      private
        def default_value?(value)
          value == coder.load(nil)
        end

        def encoded(value)
          return if default_value?(value)
          payload = coder.dump(value)
          if payload && binary? && payload.encoding != Encoding::BINARY
            payload = payload.dup if payload.frozen?
            payload.force_encoding(Encoding::BINARY)
          end
          payload
        end
    end
  end
end
