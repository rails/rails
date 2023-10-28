# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  class AttributeTest < ActiveModel::TestCase
    class InscribingType
      def changed_in_place?(raw_old_value, new_value)
        false
      end

      def cast(value)
        "cast(#{value})"
      end

      def serialize(value)
        "serialize(#{value})"
      end

      def deserialize(value)
        "deserialize(#{value})"
      end
    end

    setup do
      @type = InscribingType.new
    end

    test "from_database + read type casts from database" do
      attribute = Attribute.from_database(nil, "a value", @type)

      assert_equal "deserialize(a value)", attribute.value
    end

    test "from_user + read type casts from user" do
      attribute = Attribute.from_user(nil, "a value", @type)

      assert_equal "cast(a value)", attribute.value
    end

    test "reading memoizes the value" do
      count = 0
      @type.define_singleton_method(:deserialize) do |value|
        count += 1
        value
      end

      attribute = Attribute.from_database(nil, "whatever", @type)

      attribute.value
      attribute.value
      assert_equal 1, count
    end

    test "reading memoizes falsy values" do
      count = 0
      @type.define_singleton_method(:deserialize) do |value|
        count += 1
        false
      end

      attribute = Attribute.from_database(nil, "whatever", @type)

      attribute.value
      attribute.value
      assert_equal 1, count
    end

    test "value_before_type_cast returns the given value" do
      attribute = Attribute.from_database(nil, "raw value", @type)

      raw_value = attribute.value_before_type_cast

      assert_equal "raw value", raw_value
    end

    test "from_database + value_for_database type casts to and from database" do
      attribute = Attribute.from_database(nil, "whatever", @type)

      assert_equal "serialize(deserialize(whatever))", attribute.value_for_database
    end

    test "from_user + value_for_database type casts from the user to the database" do
      attribute = Attribute.from_user(nil, "whatever", @type)

      assert_equal "serialize(cast(whatever))", attribute.value_for_database
    end

    test "from_user + value_for_database uses serialize_cast_value when possible" do
      @type = Class.new(InscribingType) do
        include Type::SerializeCastValue

        def serialize_cast_value(value)
          "serialize_cast_value(#{value})"
        end
      end.new

      attribute = Attribute.from_user(nil, "whatever", @type)

      assert_equal "serialize_cast_value(cast(whatever))", attribute.value_for_database
    end

    test "value_for_database is memoized" do
      count = 0
      @type.define_singleton_method(:serialize) do |value|
        count += 1
        nil
      end

      attribute = Attribute.from_user(nil, "whatever", @type)

      attribute.value_for_database
      attribute.value_for_database
      assert_equal 1, count
    end

    test "value_for_database is recomputed when value changes in place" do
      count = 0
      @type.define_singleton_method(:serialize) do |value|
        count += 1
        nil
      end
      @type.define_singleton_method(:changed_in_place?) do |*|
        true
      end

      attribute = Attribute.from_user(nil, "whatever", @type)

      attribute.value_for_database
      attribute.value_for_database
      assert_equal 2, count
    end

    test "duping dups the value" do
      attribute = Attribute.from_database(nil, "a value", @type)

      assert_not_same attribute.value, attribute.dup.value
    end

    test "duping does not dup the value if it is not dupable" do
      @type.define_singleton_method(:deserialize) { |value| value }
      attribute = Attribute.from_database(nil, false, @type)

      assert_same attribute.value, attribute.dup.value
    end

    test "duping does not eagerly type cast if we have not yet type cast" do
      deserialize_called = false
      deserialize_called_with = nil
      @type.define_singleton_method(:deserialize) do |value|
        deserialize_called_with = value
        deserialize_called = true
      end
      attribute = Attribute.from_database(nil, "my_attribute_value", @type)

      attribute.dup
      assert_not deserialize_called, "deserialize should not have been called, but was called with #{deserialize_called_with}"
    end

    class MyType
      def cast(value)
        value + " from user"
      end

      def deserialize(value)
        value + " from database"
      end

      def assert_valid_value(*)
      end
    end

    test "with_value_from_user returns a new attribute with the value from the user" do
      old = Attribute.from_database(nil, "old", MyType.new)
      new = old.with_value_from_user("new")

      assert_equal "old from database", old.value
      assert_equal "new from user", new.value
    end

    test "with_value_from_database returns a new attribute with the value from the database" do
      old = Attribute.from_user(nil, "old", MyType.new)
      new = old.with_value_from_database("new")

      assert_equal "old from user", old.value
      assert_equal "new from database", new.value
    end

    test "uninitialized attributes yield their name if a block is given to value" do
      block = proc { |name| name.to_s + "!" }
      foo = Attribute.uninitialized(:foo, nil)
      bar = Attribute.uninitialized(:bar, nil)

      assert_equal "foo!", foo.value(&block)
      assert_equal "bar!", bar.value(&block)
    end

    test "uninitialized attributes have no value" do
      assert_nil Attribute.uninitialized(:foo, nil).value
    end

    test "attributes equal other attributes with the same constructor arguments" do
      first = Attribute.from_database(:foo, 1, Type::Integer.new)
      second = Attribute.from_database(:foo, 1, Type::Integer.new)
      assert_equal first, second
    end

    test "attributes do not equal attributes with different names" do
      first = Attribute.from_database(:foo, 1, Type::Integer.new)
      second = Attribute.from_database(:bar, 1, Type::Integer.new)
      assert_not_equal first, second
    end

    test "attributes do not equal attributes with different types" do
      first = Attribute.from_database(:foo, 1, Type::Integer.new)
      second = Attribute.from_database(:foo, 1, Type::Float.new)
      assert_not_equal first, second
    end

    test "attributes do not equal attributes with different values" do
      first = Attribute.from_database(:foo, 1, Type::Integer.new)
      second = Attribute.from_database(:foo, 2, Type::Integer.new)
      assert_not_equal first, second
    end

    test "attributes do not equal attributes of other classes" do
      first = Attribute.from_database(:foo, 1, Type::Integer.new)
      second = Attribute.from_user(:foo, 1, Type::Integer.new)
      assert_not_equal first, second
    end

    test "an attribute has not been read by default" do
      attribute = Attribute.from_database(:foo, 1, Type::Value.new)
      assert_not_predicate attribute, :has_been_read?
    end

    test "an attribute has been read when its value is calculated" do
      attribute = Attribute.from_database(:foo, 1, Type::Value.new)
      attribute.value
      assert_predicate attribute, :has_been_read?
    end

    test "an attribute is not changed if it hasn't been assigned or mutated" do
      attribute = Attribute.from_database(:foo, 1, Type::Value.new)

      assert_not_predicate attribute, :changed?
    end

    test "an attribute is changed if it's been assigned a new value" do
      attribute = Attribute.from_database(:foo, 1, Type::Value.new)
      changed = attribute.with_value_from_user(2)

      assert_predicate changed, :changed?
    end

    test "an attribute is not changed if it's assigned the same value" do
      attribute = Attribute.from_database(:foo, 1, Type::Value.new)
      unchanged = attribute.with_value_from_user(1)

      assert_not_predicate unchanged, :changed?
    end

    test "an attribute cannot be mutated if it has not been read,
      and skips expensive calculations" do
      type_which_raises_from_all_methods = Object.new
      attribute = Attribute.from_database(:foo, "bar", type_which_raises_from_all_methods)

      assert_not_predicate attribute, :changed_in_place?
    end

    test "an attribute is changed if it has been mutated" do
      attribute = Attribute.from_database(:foo, "bar", Type::String.new)
      attribute.value << "!"

      assert_predicate attribute, :changed_in_place?
      assert_predicate attribute, :changed?
    end

    test "an attribute can forget its changes" do
      attribute = Attribute.from_database(:foo, "bar", Type::String.new)
      changed = attribute.with_value_from_user("foo")
      forgotten = changed.forgetting_assignment

      assert_predicate changed, :changed? # Check to avoid a false positive
      assert_not_predicate forgotten, :changed?
    end

    test "#forgetting_assignment on an unchanged .from_database attribute re-deserializes its value" do
      deserialized_value_class = Struct.new(:id) do
        def initialize_dup(*)
          self.id = nil # a la ActiveRecord::Base#dup
        end
      end

      type = Type::Value.new
      type.define_singleton_method(:deserialize) do |value|
        deserialized_value_class.new(value)
      end

      original = Attribute.from_database(:foo, 123, type)
      assert_equal 123, original.value.id

      forgotten = original.forgetting_assignment
      assert_equal 123, forgotten.value.id

      assert_not_same original.value, forgotten.value
    end

    test "with_value_from_user validates the value" do
      type = Type::Value.new
      type.define_singleton_method(:assert_valid_value) do |value|
        if value == 1
          raise ArgumentError
        end
      end

      attribute = Attribute.from_database(:foo, 1, type)
      assert_equal 1, attribute.value
      assert_equal 2, attribute.with_value_from_user(2).value
      assert_raises ArgumentError do
        attribute.with_value_from_user(1)
      end
    end

    test "with_type preserves mutations" do
      attribute = Attribute.from_database(:foo, +"", Type::Value.new)
      attribute.value << "1"

      assert_equal 1, attribute.with_type(Type::Integer.new).value
    end
  end
end
