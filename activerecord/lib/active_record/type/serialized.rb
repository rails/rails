# frozen_string_literal: true

module ActiveRecord
  module Type
    class Serialized < ActiveSupport::Delegation::DelegateClass(ActiveModel::Type::Value) # :nodoc:
      undef to_yaml if method_defined?(:to_yaml)

      include ActiveModel::Type::Helpers::Mutable

      attr_reader :subtype, :coder

      def initialize(subtype, coder, comparable: false)
        @subtype = subtype
        @coder = coder
        @comparable = comparable
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

      define_method(:inspect, Kernel.instance_method(:inspect))

      def changed_in_place?(raw_old_value, value)
        return false if value.nil?

        if @comparable
          old_value = deserialize(raw_old_value)
          old_value != value
        else
          raw_new_value = encoded(value)
          raw_old_value.nil? != raw_new_value.nil? ||
            subtype.changed_in_place?(raw_old_value, raw_new_value)
        end
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

      def serialized? # :nodoc:
        true
      end

      private
        # Prevent Ruby 4.0 "delegator does not forward private method" warning.
        # Kernel#inspect calls instance_variables_to_inspect which, without this,
        # triggers Delegator#respond_to_missing? for a private method.
        define_method(:instance_variables_to_inspect, Kernel.instance_method(:instance_variables))

        def default_value?(value)
          value == coder.load(nil)
        end

        def encoded(value)
          return if default_value?(value)
          payload = coder.dump(value)
          if payload && @subtype.binary?
            ActiveModel::Type::Binary::Data.new(payload)
          else
            payload
          end
        end
    end
  end
end
