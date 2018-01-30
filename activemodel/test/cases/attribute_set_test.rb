# frozen_string_literal: true

require "cases/helper"
require "active_model/attribute_set"

module ActiveModel
  class AttributeSetTest < ActiveModel::TestCase
    test "building a new set from raw attributes" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: "1.1", bar: "2.2")

      assert_equal 1, attributes[:foo].value
      assert_equal 2.2, attributes[:bar].value
      assert_equal :foo, attributes[:foo].name
      assert_equal :bar, attributes[:bar].name
    end

    test "building with custom types" do
      builder = AttributeSet::Builder.new(foo: Type::Float.new)
      attributes = builder.build_from_database({ foo: "3.3", bar: "4.4" }, { bar: Type::Integer.new })

      assert_equal 3.3, attributes[:foo].value
      assert_equal 4, attributes[:bar].value
    end

    test "[] returns a null object" do
      builder = AttributeSet::Builder.new(foo: Type::Float.new)
      attributes = builder.build_from_database(foo: "3.3")

      assert_equal "3.3", attributes[:foo].value_before_type_cast
      assert_nil attributes[:bar].value_before_type_cast
      assert_equal :bar, attributes[:bar].name
    end

    test "duping creates a new hash, but does not dup the attributes" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::String.new)
      attributes = builder.build_from_database(foo: 1, bar: "foo")

      # Ensure the type cast value is cached
      attributes[:foo].value
      attributes[:bar].value

      duped = attributes.dup
      duped.write_from_database(:foo, 2)
      duped[:bar].value << "bar"

      assert_equal 1, attributes[:foo].value
      assert_equal 2, duped[:foo].value
      assert_equal "foobar", attributes[:bar].value
      assert_equal "foobar", duped[:bar].value
    end

    test "deep_duping creates a new hash and dups each attribute" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::String.new)
      attributes = builder.build_from_database(foo: 1, bar: "foo")

      # Ensure the type cast value is cached
      attributes[:foo].value
      attributes[:bar].value

      duped = attributes.deep_dup
      duped.write_from_database(:foo, 2)
      duped[:bar].value << "bar"

      assert_equal 1, attributes[:foo].value
      assert_equal 2, duped[:foo].value
      assert_equal "foo", attributes[:bar].value
      assert_equal "foobar", duped[:bar].value
    end

    test "freezing cloned set does not freeze original" do
      attributes = AttributeSet.new({})
      clone = attributes.clone

      clone.freeze

      assert_predicate clone, :frozen?
      assert_not_predicate attributes, :frozen?
    end

    test "to_hash returns a hash of the type cast values" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: "1.1", bar: "2.2")

      assert_equal({ foo: 1, bar: 2.2 }, attributes.to_hash)
      assert_equal({ foo: 1, bar: 2.2 }, attributes.to_h)
    end

    test "to_hash maintains order" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: "2.2", bar: "3.3")

      attributes[:bar]
      hash = attributes.to_h

      assert_equal [[:foo, 2], [:bar, 3.3]], hash.to_a
    end

    test "values_before_type_cast" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Integer.new)
      attributes = builder.build_from_database(foo: "1.1", bar: "2.2")

      assert_equal({ foo: "1.1", bar: "2.2" }, attributes.values_before_type_cast)
    end

    test "known columns are built with uninitialized attributes" do
      attributes = attributes_with_uninitialized_key
      assert_predicate attributes[:foo], :initialized?
      assert_not_predicate attributes[:bar], :initialized?
    end

    test "uninitialized attributes are not included in the attributes hash" do
      attributes = attributes_with_uninitialized_key
      assert_equal({ foo: 1 }, attributes.to_hash)
    end

    test "uninitialized attributes are not included in keys" do
      attributes = attributes_with_uninitialized_key
      assert_equal [:foo], attributes.keys
    end

    test "uninitialized attributes return false for key?" do
      attributes = attributes_with_uninitialized_key
      assert attributes.key?(:foo)
      assert_not attributes.key?(:bar)
    end

    test "unknown attributes return false for key?" do
      attributes = attributes_with_uninitialized_key
      assert_not attributes.key?(:wibble)
    end

    test "fetch_value returns the value for the given initialized attribute" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: "1.1", bar: "2.2")

      assert_equal 1, attributes.fetch_value(:foo)
      assert_equal 2.2, attributes.fetch_value(:bar)
    end

    test "fetch_value returns nil for unknown attributes" do
      attributes = attributes_with_uninitialized_key
      assert_nil attributes.fetch_value(:wibble) { "hello" }
    end

    test "fetch_value returns nil for unknown attributes when types has a default" do
      types = Hash.new(Type::Value.new)
      builder = AttributeSet::Builder.new(types)
      attributes = builder.build_from_database

      assert_nil attributes.fetch_value(:wibble) { "hello" }
    end

    test "fetch_value uses the given block for uninitialized attributes" do
      attributes = attributes_with_uninitialized_key
      value = attributes.fetch_value(:bar) { |n| n.to_s + "!" }
      assert_equal "bar!", value
    end

    test "fetch_value returns nil for uninitialized attributes if no block is given" do
      attributes = attributes_with_uninitialized_key
      assert_nil attributes.fetch_value(:bar)
    end

    test "the primary_key is always initialized" do
      defaults = { foo: Attribute.from_user(:foo, nil, nil) }
      builder = AttributeSet::Builder.new({ foo: Type::Integer.new }, defaults)
      attributes = builder.build_from_database

      assert attributes.key?(:foo)
      assert_equal [:foo], attributes.keys
      assert_predicate attributes[:foo], :initialized?
    end

    class MyType
      def cast(value)
        return if value.nil?
        value + " from user"
      end

      def deserialize(value)
        return if value.nil?
        value + " from database"
      end

      def assert_valid_value(*)
      end
    end

    test "write_from_database sets the attribute with database typecasting" do
      builder = AttributeSet::Builder.new(foo: MyType.new)
      attributes = builder.build_from_database

      assert_nil attributes.fetch_value(:foo)

      attributes.write_from_database(:foo, "value")

      assert_equal "value from database", attributes.fetch_value(:foo)
    end

    test "write_from_user sets the attribute with user typecasting" do
      builder = AttributeSet::Builder.new(foo: MyType.new)
      attributes = builder.build_from_database

      assert_nil attributes.fetch_value(:foo)

      attributes.write_from_user(:foo, "value")

      assert_equal "value from user", attributes.fetch_value(:foo)
    end

    test "freezing doesn't prevent the set from materializing" do
      builder = AttributeSet::Builder.new(foo: Type::String.new)
      attributes = builder.build_from_database(foo: "1")

      attributes.freeze
      assert_equal({ foo: "1" }, attributes.to_hash)
    end

    test "marshaling dump/load legacy materialized attribute hash" do
      builder = AttributeSet::Builder.new(foo: Type::String.new)
      attributes = builder.build_from_database(foo: "1")

      attributes.fetch(:foo) # force materialized
      attributes = Marshal.load(Marshal.dump(attributes))

      assert_equal({ foo: "1" }, attributes.to_hash)
    end

    test "#accessed_attributes returns only attributes which have been read" do
      builder = AttributeSet::Builder.new(foo: Type::Value.new, bar: Type::Value.new)
      attributes = builder.build_from_database(foo: "1", bar: "2")

      assert_equal [], attributes.accessed

      attributes.fetch_value(:foo)

      assert_equal [:foo], attributes.accessed
    end

    test "#map returns a new attribute set with the changes applied" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Integer.new)
      attributes = builder.build_from_database(foo: "1", bar: "2")
      new_attributes = attributes.map do |attr|
        attr.with_cast_value(attr.value + 1)
      end

      assert_equal 2, new_attributes.fetch_value(:foo)
      assert_equal 3, new_attributes.fetch_value(:bar)
    end

    test "comparison for equality is correctly implemented" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Integer.new)
      attributes = builder.build_from_database(foo: "1", bar: "2")
      attributes2 = builder.build_from_database(foo: "1", bar: "2")
      attributes3 = builder.build_from_database(foo: "2", bar: "2")

      assert_equal attributes, attributes2
      assert_not_equal attributes2, attributes3
    end

    private
      def attributes_with_uninitialized_key
        builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
        builder.build_from_database(foo: "1.1")
      end
  end
end
