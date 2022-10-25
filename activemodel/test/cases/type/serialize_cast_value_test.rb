# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class SerializeCastValueTest < ActiveModel::TestCase
      class DoesNotIncludeModule
        def serialize(value)
          "serialize(#{value})"
        end
      end

      class IncludesModule < DoesNotIncludeModule
        include SerializeCastValue

        def serialize_cast_value(value)
          "serialize_cast_value(#{super})"
        end
      end

      test "provides a default #serialize_cast_value implementation" do
        type = Class.new(DoesNotIncludeModule) { include SerializeCastValue }
        assert_equal "foo", type.new.serialize_cast_value("foo")
      end

      test "uses #serialize when a class does not include SerializeCastValue" do
        assert_serializes_using :serialize, DoesNotIncludeModule.new
      end

      test "uses #serialize_cast_value when a class includes SerializeCastValue" do
        assert_serializes_using :serialize_cast_value, IncludesModule.new
      end

      test "uses #serialize_cast_value when a subclass inherits both #serialize and #serialize_cast_value" do
        subclass = Class.new(IncludesModule)
        assert_serializes_using :serialize_cast_value, subclass.new
      end

      test "uses #serialize when a subclass defines a newer #serialize implementation" do
        subclass = Class.new(IncludesModule) { def serialize(value); super; end }
        assert_serializes_using :serialize, subclass.new
      end

      test "uses #serialize_cast_value when a subclass defines a newer #serialize_cast_value implementation" do
        subclass = Class.new(IncludesModule) { def serialize_cast_value(value); super; end }
        assert_serializes_using :serialize_cast_value, subclass.new
      end

      test "uses #serialize when a subclass defines a newer #serialize implementation via a module" do
        mod = Module.new { def serialize(value); super; end }
        subclass = Class.new(IncludesModule) { include mod }
        assert_serializes_using :serialize, subclass.new
      end

      test "uses #serialize_cast_value when a subclass defines a newer #serialize_cast_value implementation via a module" do
        mod = Module.new { def serialize_cast_value(value); super; end }
        subclass = Class.new(IncludesModule) { include mod }
        assert_serializes_using :serialize_cast_value, subclass.new
      end

      test "uses #serialize when a delegate class does not include SerializeCastValue" do
        delegate_class = DelegateClass(IncludesModule)
        assert_serializes_using :serialize, delegate_class.new(IncludesModule.new)
      end

      test "uses #serialize_cast_value when a delegate class prepends SerializeCastValue" do
        delegate_class = DelegateClass(IncludesModule) { prepend SerializeCastValue }
        assert_serializes_using :serialize_cast_value, delegate_class.new(IncludesModule.new)
      end

      test "uses #serialize_cast_value when a delegate class subclass includes SerializeCastValue" do
        delegate_subclass = Class.new(DelegateClass(IncludesModule)) { include SerializeCastValue }
        assert_serializes_using :serialize_cast_value, delegate_subclass.new(IncludesModule.new)
      end

      private
        def assert_serializes_using(method_name, type)
          assert_equal "#{method_name}(foo)", SerializeCastValue.serialize(type, "foo")
        end
    end
  end
end
