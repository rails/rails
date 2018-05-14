# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class AdapterSpecificRegistryTest < ActiveRecord::TestCase
    test "a class can be registered for a symbol" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, ::String)
      registry.register(:bar, ::Array)

      assert_equal "", registry.lookup(:foo)
      assert_equal [], registry.lookup(:bar)
    end

    test "a block can be registered" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo) do |*args|
        [*args, "block for foo"]
      end
      registry.register(:bar) do |*args|
        [*args, "block for bar"]
      end

      assert_equal [:foo, 1, "block for foo"], registry.lookup(:foo, 1)
      assert_equal [:foo, 2, "block for foo"], registry.lookup(:foo, 2)
      assert_equal [:bar, 1, 2, 3, "block for bar"], registry.lookup(:bar, 1, 2, 3)
    end

    test "filtering by adapter" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String, adapter: :sqlite3)
      registry.register(:foo, Array, adapter: :postgresql)

      assert_equal "", registry.lookup(:foo, adapter: :sqlite3)
      assert_equal [], registry.lookup(:foo, adapter: :postgresql)
    end

    test "an error is raised if both a generic and adapter specific type match" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String)
      registry.register(:foo, Array, adapter: :postgresql)

      assert_raises TypeConflictError do
        registry.lookup(:foo, adapter: :postgresql)
      end
      assert_equal "", registry.lookup(:foo, adapter: :sqlite3)
    end

    test "a generic type can explicitly override an adapter specific type" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String, override: true)
      registry.register(:foo, Array, adapter: :postgresql)

      assert_equal "", registry.lookup(:foo, adapter: :postgresql)
      assert_equal "", registry.lookup(:foo, adapter: :sqlite3)
    end

    test "a generic type can explicitly allow an adapter type to be used instead" do
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String, override: false)
      registry.register(:foo, Array, adapter: :postgresql)

      assert_equal [], registry.lookup(:foo, adapter: :postgresql)
      assert_equal "", registry.lookup(:foo, adapter: :sqlite3)
    end

    test "a reasonable error is given when no type is found" do
      registry = Type::AdapterSpecificRegistry.new

      e = assert_raises(ArgumentError) do
        registry.lookup(:foo)
      end

      assert_equal "Unknown type :foo", e.message
    end

    test "construct args are passed to the type" do
      type = Struct.new(:args)
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, type)

      assert_equal type.new, registry.lookup(:foo)
      assert_equal type.new(:ordered_arg), registry.lookup(:foo, :ordered_arg)
      assert_equal type.new(keyword: :arg), registry.lookup(:foo, keyword: :arg)
      assert_equal type.new(keyword: :arg), registry.lookup(:foo, keyword: :arg, adapter: :postgresql)
    end

    test "registering a modifier" do
      decoration = Struct.new(:value)
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String)
      registry.register(:bar, Hash)
      registry.add_modifier({ array: true }, decoration)

      assert_equal decoration.new(""), registry.lookup(:foo, array: true)
      assert_equal decoration.new({}), registry.lookup(:bar, array: true)
      assert_equal "", registry.lookup(:foo)
    end

    test "registering multiple modifiers" do
      decoration = Struct.new(:value)
      other_decoration = Struct.new(:value)
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, String)
      registry.add_modifier({ array: true }, decoration)
      registry.add_modifier({ range: true }, other_decoration)

      assert_equal "", registry.lookup(:foo)
      assert_equal decoration.new(""), registry.lookup(:foo, array: true)
      assert_equal other_decoration.new(""), registry.lookup(:foo, range: true)
      assert_equal(
        decoration.new(other_decoration.new("")),
        registry.lookup(:foo, array: true, range: true)
      )
    end

    test "registering adapter specific modifiers" do
      decoration = Struct.new(:value)
      type = Struct.new(:args)
      registry = Type::AdapterSpecificRegistry.new
      registry.register(:foo, type)
      registry.add_modifier({ array: true }, decoration, adapter: :postgresql)

      assert_equal(
        decoration.new(type.new(keyword: :arg)),
        registry.lookup(:foo, array: true, adapter: :postgresql, keyword: :arg)
      )
      assert_equal(
        type.new(array: true),
        registry.lookup(:foo, array: true, adapter: :sqlite3)
      )
    end
  end
end
