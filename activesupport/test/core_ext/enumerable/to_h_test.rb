require 'abstract_unit'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/enumerable'

class EnumerableToHTest < ActiveSupport::TestCase
  test "to_h converts an array of tuples to a hash" do
    assert_equal({ 'a' => 1, 'b' => 2 }, [['a', 1], ['b', 2]].to_h)
  end

  test "to_h works with any enumerable" do
    assert_equal({ a: :b, b: :c }, Yielder.to_h([:a, :b], [:b, :c]).to_h)
  end

  test "to_h on a hash returns self" do
    hash = { a: :b }
    assert_same(hash, hash.to_h)

    assert_raises(ArgumentError) do
      hash.to_h('foo')
    end
  end

  test "to_h on a HashWithIndifferentAccess converts to a Hash" do
    hash = { a: :b }.with_indifferent_access

    assert_not_same(hash, hash.to_h)
    assert_equal({ 'a' => :b }, hash.to_h)
    assert_instance_of(Hash, hash.to_h)
  end

  test "to_h on a random hash subclass converts to a Hash" do
    klass = Class.new(Hash)
    hash = klass.new

    assert_not_same(hash, hash.to_h)
    assert_equal({}, hash.to_h)
    assert_instance_of(Hash, hash.to_h)
  end

  test "to_h raises if each yields a non-array" do
    e = assert_raises(TypeError) do
      Yielder.to_h(Object.new)
    end
    assert_equal("wrong element type Object (expected array)", e.message)

    e = assert_raises(TypeError) do
      Yielder.to_h("foo")
    end
    assert_equal("wrong element type String (expected array)", e.message)
  end

  test "to_h raises if each yields an array with the wrong number of elements" do
    e = assert_raises(ArgumentError) do
      Yielder.to_h([1])
    end
    assert_equal("element has wrong array length (expected 2, was 1)", e.message)

    e = assert_raises(ArgumentError) do
      Yielder.to_h([1, 2, 3])
    end
    assert_equal("element has wrong array length (expected 2, was 3)", e.message)
  end

  test "to_h on nil returns an empty hash" do
    assert_equal({}, nil.to_h)
  end

  test "to_h is defined on NilClass, not nil singleton" do
    assert NilClass.instance_method(:to_h)
  end

  test "to_h on an array of non-arrays raises" do
    e = assert_raises(TypeError) do
      [Object.new].to_h
    end
    assert_equal("wrong element type Object at 0 (expected array)", e.message)

    e = assert_raises(TypeError) do
      [[1, 2], "foo"].to_h
    end
    assert_equal("wrong element type String at 1 (expected array)", e.message)
  end

  test "to_h on an array with a sub-array of the wrong length raises" do
    e = assert_raises(ArgumentError) do
      [[1]].to_h
    end
    assert_equal("wrong array length at 0 (expected 2, was 1)", e.message)

    e = assert_raises(ArgumentError) do
      [[1, 2], [1, 2, 3]].to_h
    end
    assert_equal("wrong array length at 1 (expected 2, was 3)", e.message)
  end

  test "to_h on ENV converts to a hash" do
    assert_equal(ENV.to_hash, ENV.to_h)
  end

  unless RUBY_VERSION == '1.9.3' || RUBY_VERSION.start_with?('2.0')
    test "Enumerable#to_h is not overridden" do
      assert_nil Enumerable.instance_method(:to_h).source_location
    end

    test "Array#to_h is not overridden" do
      assert_nil Array.instance_method(:to_h).source_location
    end

    test "Hash#to_h is not overridden" do
      assert_nil Hash.instance_method(:to_h).source_location
    end

    test "NilClass#to_h is not overridden" do
      assert_nil NilClass.instance_method(:to_h).source_location
    end

    test "ENV.to_h is not overridden" do
      assert_nil ENV.method(:to_h).source_location
    end
  end

  class Yielder
    extend Enumerable

    def self.each(*args)
      args.each do |pair|
        yield pair
      end
    end
  end
end
