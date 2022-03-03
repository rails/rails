# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class SerializeCastValueTest < ActiveModel::TestCase
      class DoesNotIncludeModule
        def serialize(value)
          "serialize(#{value})"
        end

        def serialize_cast_value(value)
          raise "this should never be called"
        end
      end

      class IncludesModule < DoesNotIncludeModule
        include SerializeCastValue

        def serialize_cast_value(value)
          super("serialize_cast_value(#{value})")
        end
      end

      test "calls #serialize when a class does not include SerializeCastValue" do
        assert_equal "serialize(foo)", SerializeCastValue.serialize(DoesNotIncludeModule.new, "foo")
      end

      test "calls #serialize_cast_value when a class directly includes SerializeCastValue" do
        assert_equal "serialize_cast_value(foo)", SerializeCastValue.serialize(IncludesModule.new, "foo")
      end

      test "calls #serialize when a subclass does not directly include SerializeCastValue" do
        subclass = Class.new(IncludesModule)
        assert_equal "serialize(foo)", SerializeCastValue.serialize(subclass.new, "foo")
      end

      test "calls #serialize_cast_value when a subclass re-includes SerializeCastValue" do
        subclass = Class.new(IncludesModule)
        subclass.include SerializeCastValue
        assert_equal "serialize_cast_value(foo)", SerializeCastValue.serialize(subclass.new, "foo")
      end

      test "calls #serialize when a delegate class does not include SerializeCastValue" do
        delegate_class = DelegateClass(IncludesModule)
        assert_equal "serialize(foo)", SerializeCastValue.serialize(delegate_class.new(IncludesModule.new), "foo")
      end

      test "calls #serialize_cast_value when a delegate class includes SerializeCastValue" do
        delegate_class = DelegateClass(IncludesModule)
        delegate_class.include SerializeCastValue
        assert_equal "serialize_cast_value(foo)", SerializeCastValue.serialize(delegate_class.new(IncludesModule.new), "foo")
      end
    end
  end
end
