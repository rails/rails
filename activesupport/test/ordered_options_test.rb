# frozen_string_literal: true

require "pp"
require_relative "abstract_unit"
require "active_support/ordered_options"

class OrderedOptionsTest < ActiveSupport::TestCase
  def test_usage
    a = ActiveSupport::OrderedOptions.new

    assert_nil a[:not_set]

    a[:allow_concurrency] = true
    assert_equal 1, a.size
    assert a[:allow_concurrency]

    a[:allow_concurrency] = false
    assert_equal 1, a.size
    assert_not a[:allow_concurrency]

    a["else_where"] = 56
    assert_equal 2, a.size
    assert_equal 56, a[:else_where]
  end

  def test_looping
    a = ActiveSupport::OrderedOptions.new

    a[:allow_concurrency] = true
    a["else_where"] = 56

    test = [[:allow_concurrency, true], [:else_where, 56]]

    a.each_with_index do |(key, value), index|
      assert_equal test[index].first, key
      assert_equal test[index].last, value
    end
  end

  def test_string_dig
    a = ActiveSupport::OrderedOptions.new

    a[:test_key] = 56
    assert_equal 56, a.test_key
    assert_equal 56, a["test_key"]
    assert_equal 56, a.dig(:test_key)
    assert_equal 56, a.dig("test_key")
  end

  def test_nested_dig
    a = ActiveSupport::OrderedOptions.new

    a[:test_key] = [{ a: 1 }]
    assert_equal 1, a.dig(:test_key, 0, :a)
    assert_nil a.dig(:test_key, 1, :a)
  end

  def test_method_access
    a = ActiveSupport::OrderedOptions.new

    assert_nil a.not_set

    a.allow_concurrency = true
    assert_equal 1, a.size
    assert a.allow_concurrency

    a.allow_concurrency = false
    assert_equal 1, a.size
    assert_not a.allow_concurrency

    a.else_where = 56
    assert_equal 2, a.size
    assert_equal 56, a.else_where
  end

  def test_inheritable_options_continues_lookup_in_parent
    parent = ActiveSupport::OrderedOptions.new
    parent[:foo] = true

    child = ActiveSupport::InheritableOptions.new(parent)
    assert child.foo
  end

  def test_inheritable_options_can_override_parent
    parent = ActiveSupport::OrderedOptions.new
    parent[:foo] = :bar

    child = ActiveSupport::InheritableOptions.new(parent)
    child[:foo] = :baz

    assert_equal :baz, child.foo
  end

  def test_inheritable_options_inheritable_copy
    original = ActiveSupport::InheritableOptions.new
    copy     = original.inheritable_copy

    assert copy.kind_of?(original.class)
    assert_not_equal copy.object_id, original.object_id
  end

  def test_introspection
    a = ActiveSupport::OrderedOptions.new
    assert_respond_to a, :blah
    assert_respond_to a, :blah=
    assert_equal 42, a.method(:blah=).call(42)
    assert_equal 42, a.method(:blah).call
  end

  def test_raises_with_bang
    a = ActiveSupport::OrderedOptions.new
    a[:foo] = :bar
    assert_respond_to a, :foo!

    assert_nothing_raised { a.foo! }
    assert_equal a.foo, a.foo!

    assert_raises(KeyError) do
      a.foo = nil
      a.foo!
    end
    assert_raises(KeyError) { a.non_existing_key! }
  end

  def test_inheritable_options_with_bang
    a = ActiveSupport::InheritableOptions.new(foo: :bar)

    assert_nothing_raised { a.foo! }
    assert_equal a.foo, a.foo!

    assert_raises(KeyError) do
      a.foo = nil
      a.foo!
    end
    assert_raises(KeyError) { a.non_existing_key! }
  end

  def test_ordered_option_inspect
    a = ActiveSupport::OrderedOptions.new
    assert_equal "#<ActiveSupport::OrderedOptions {}>", a.inspect

    a.foo   = :bar
    a[:baz] = :quz

    assert_equal "#<ActiveSupport::OrderedOptions #{{ foo: :bar, baz: :quz }}>", a.inspect
  end

  def test_inheritable_option_inspect
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    assert_equal "#<ActiveSupport::InheritableOptions #{{ one: "first value" }}>", object.inspect

    object[:two] = "second value"
    object["three"] = "third value"
    assert_equal "#<ActiveSupport::InheritableOptions #{{ one: "first value", two: "second value", three: "third value" }}>", object.inspect
  end

  def test_ordered_options_to_h
    object = ActiveSupport::OrderedOptions.new
    assert_equal({}, object.to_h)
    object.one = "first value"
    object[:two] = "second value"
    object["three"] = "third value"

    assert_equal({ one: "first value", two: "second value", three: "third value" }, object.to_h)
  end

  def test_inheritable_options_to_h
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    assert_equal({ one: "first value" }, object.to_h)

    object[:two] = "second value"
    object["three"] = "third value"

    assert_equal({ one: "first value", two: "second value", three: "third value" }, object.to_h)
  end

  def test_ordered_options_dup
    object = ActiveSupport::OrderedOptions.new
    object.one = "first value"
    object[:two] = "second value"
    object["three"] = "third value"

    duplicate = object.dup
    assert_equal object, duplicate
    assert_not_equal object.object_id, duplicate.object_id
  end

  def test_inheritable_options_dup
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    object[:two] = "second value"
    object["three"] = "third value"

    duplicate = object.dup
    assert_equal object, duplicate
    assert_not_equal object.object_id, duplicate.object_id
  end

  def test_ordered_options_key
    object = ActiveSupport::OrderedOptions.new
    object.one = "first value"
    object[:two] = "second value"
    object["three"] = "third value"

    assert object.key?(:one)
    assert_not object.key?("one")
    assert object.key?(:two)
    assert_not object.key?("two")
    assert object.key?(:three)
    assert_not object.key?("three")
    assert_not object.key?(:four)
  end

  def test_inheritable_options_key
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    object[:two] = "second value"
    object["three"] = "third value"

    assert object.key?(:one)
    assert_not object.key?("one")
    assert object.key?(:two)
    assert_not object.key?("two")
    assert object.key?(:three)
    assert_not object.key?("three")
    assert_not object.key?(:four)
  end

  def test_inheritable_options_overridden
    object = ActiveSupport::InheritableOptions.new(one: "first value", two: "second value", three: "third value")
    object["one"] = "first value override"
    object[:two] = "second value override"

    assert object.overridden?(:one)
    assert_equal "first value override", object.one
    assert object.overridden?(:two)
    assert_equal "second value override", object.two
    assert_not object.overridden?(:three)
    assert_equal "third value", object.three
  end

  def test_inheritable_options_overridden_with_nil
    object = ActiveSupport::InheritableOptions.new
    object["one"] = "first value override"
    object[:two] = "second value override"

    assert_not object.overridden?(:one)
    assert_equal "first value override", object.one
    assert_not object.overridden?(:two)
    assert_equal "second value override", object.two
  end

  def test_inheritable_options_each
    object = ActiveSupport::InheritableOptions.new(one: "first value", two: "second value")
    object["one"] = "first value override"
    object[:three] = "third value"

    count = 0
    keys = []
    object.each do |key, value|
      count += 1
      keys << key
    end
    assert_equal 3, count
    assert_equal [:one, :two, :three], keys
  end

  def test_inheritable_options_to_a
    object = ActiveSupport::InheritableOptions.new(one: "first value", two: "second value")
    object["one"] = "first value override"
    object[:three] = "third value"

    assert_equal [[:one, "first value override"], [:two, "second value"], [:three, "third value"]], object.entries
    assert_equal [[:one, "first value override"], [:two, "second value"], [:three, "third value"]], object.to_a
  end

  def test_inheritable_options_count
    object = ActiveSupport::InheritableOptions.new(one: "first value", two: "second value")
    object["one"] = "first value override"
    object[:three] = "third value"

    assert_equal 3, object.count
  end

  def test_ordered_options_to_s
    object = ActiveSupport::OrderedOptions.new
    assert_equal "{}", object.to_s

    object.one = "first value"
    object[:two] = "second value"
    object["three"] = "third value"

    assert_equal({ one: "first value", two: "second value", three: "third value" }.inspect, object.to_s)
  end

  def test_inheritable_options_to_s
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    assert_equal({ one: "first value" }.inspect, object.to_s)

    object[:two] = "second value"
    object["three"] = "third value"
    assert_equal({ one: "first value", two: "second value", three: "third value" }.inspect, object.to_s)
  end

  def test_odrered_options_pp
    object = ActiveSupport::OrderedOptions.new
    object.one = "first value"
    object[:two] = "second value"
    object["three"] = "third value"

    io = StringIO.new
    PP.pp(object, io)
    assert_equal({ one: "first value", two: "second value", three: "third value" }.inspect, io.string.strip)
  end

  def test_inheritable_options_pp
    object = ActiveSupport::InheritableOptions.new(one: "first value")
    object[:two] = "second value"
    object["three"] = "third value"
    assert_equal({ one: "first value", two: "second value", three: "third value" }.inspect, object.to_s)

    io = StringIO.new
    PP.pp(object, io)
    assert_equal({ one: "first value", two: "second value", three: "third value" }.inspect, io.string.strip)
  end
end
