require 'cases/helper'

module ActiveRecord
  class AttributeSetTest < ActiveRecord::TestCase
    test "building a new set from raw attributes" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: '1.1', bar: '2.2')

      assert_equal 1, attributes[:foo].value
      assert_equal 2.2, attributes[:bar].value
    end

    test "building with custom types" do
      builder = AttributeSet::Builder.new(foo: Type::Float.new)
      attributes = builder.build_from_database({ foo: '3.3', bar: '4.4' }, { bar: Type::Integer.new })

      assert_equal 3.3, attributes[:foo].value
      assert_equal 4, attributes[:bar].value
    end

    test "[] returns a null object" do
      builder = AttributeSet::Builder.new(foo: Type::Float.new)
      attributes = builder.build_from_database(foo: '3.3')

      assert_equal '3.3', attributes[:foo].value_before_type_cast
      assert_equal nil, attributes[:bar].value_before_type_cast
    end

    test "duping creates a new hash and dups each attribute" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::String.new)
      attributes = builder.build_from_database(foo: 1, bar: 'foo')

      # Ensure the type cast value is cached
      attributes[:foo].value
      attributes[:bar].value

      duped = attributes.dup
      duped[:foo] = Attribute.from_database(2, Type::Integer.new)
      duped[:bar].value << 'bar'

      assert_equal 1, attributes[:foo].value
      assert_equal 2, duped[:foo].value
      assert_equal 'foo', attributes[:bar].value
      assert_equal 'foobar', duped[:bar].value
    end

    test "freezing cloned set does not freeze original" do
      attributes = AttributeSet.new({})
      clone = attributes.clone

      clone.freeze

      assert clone.frozen?
      assert_not attributes.frozen?
    end

    test "to_hash returns a hash of the type cast values" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: '1.1', bar: '2.2')

      assert_equal({ foo: 1, bar: 2.2 }, attributes.to_hash)
      assert_equal({ foo: 1, bar: 2.2 }, attributes.to_h)
    end

    test "values_before_type_cast" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Integer.new)
      attributes = builder.build_from_database(foo: '1.1', bar: '2.2')

      assert_equal({ foo: '1.1', bar: '2.2' }, attributes.values_before_type_cast)
    end

    test "known columns are built with uninitialized attributes" do
      attributes = attributes_with_uninitialized_key
      assert attributes[:foo].initialized?
      assert_not attributes[:bar].initialized?
    end

    test "uninitialized attributes are not included in the attributes hash" do
      attributes = attributes_with_uninitialized_key
      assert_equal({ foo: 1 }, attributes.to_hash)
    end

    test "uninitialized attributes are not included in keys" do
      attributes = attributes_with_uninitialized_key
      assert_equal [:foo], attributes.keys
    end

    test "uninitialized attributes return false for include?" do
      attributes = attributes_with_uninitialized_key
      assert attributes.include?(:foo)
      assert_not attributes.include?(:bar)
    end

    test "unknown attributes return false for include?" do
      attributes = attributes_with_uninitialized_key
      assert_not attributes.include?(:wibble)
    end

    test "fetch_value returns the value for the given initialized attribute" do
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      attributes = builder.build_from_database(foo: '1.1', bar: '2.2')

      assert_equal 1, attributes.fetch_value(:foo)
      assert_equal 2.2, attributes.fetch_value(:bar)
    end

    test "fetch_value returns nil for unknown attributes" do
      attributes = attributes_with_uninitialized_key
      assert_nil attributes.fetch_value(:wibble)
    end

    test "fetch_value uses the given block for uninitialized attributes" do
      attributes = attributes_with_uninitialized_key
      value = attributes.fetch_value(:bar) { |n| n.to_s + '!' }
      assert_equal 'bar!', value
    end

    test "fetch_value returns nil for uninitialized attributes if no block is given" do
      attributes = attributes_with_uninitialized_key
      assert_nil attributes.fetch_value(:bar)
    end

    def attributes_with_uninitialized_key
      builder = AttributeSet::Builder.new(foo: Type::Integer.new, bar: Type::Float.new)
      builder.build_from_database(foo: '1.1')
    end
  end
end
