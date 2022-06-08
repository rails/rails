# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/ordered_options"

class ConfigurationOptionsTest < ActiveSupport::TestCase
  def test_usage
    a = ActiveSupport::ConfigurationOptions.new

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
    a = ActiveSupport::ConfigurationOptions.new

    a[:allow_concurrency] = true
    a["else_where"] = 56

    test = [[:allow_concurrency, true], [:else_where, 56]]

    a.each_with_index do |(key, value), index|
      assert_equal test[index].first, key
      assert_equal test[index].last, value
    end
  end

  def test_string_dig
    a = ActiveSupport::ConfigurationOptions.new

    a[:test_key] = 56
    assert_equal 56, a.test_key
    assert_equal 56, a["test_key"]
    assert_equal 56, a.dig(:test_key)
    assert_equal 56, a.dig("test_key")
  end

  def test_method_access
    a = ActiveSupport::ConfigurationOptions.new

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
    parent = ActiveSupport::ConfigurationOptions.new
    parent[:foo] = true

    child = ActiveSupport::InheritableOptions.new(parent)
    assert child.foo
  end

  def test_inheritable_options_can_override_parent
    parent = ActiveSupport::ConfigurationOptions.new
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
    a = ActiveSupport::ConfigurationOptions.new
    assert_respond_to a, :blah
    assert_respond_to a, :blah=
    assert_equal 42, a.method(:blah=).call(42)
    assert_equal 42, a.method(:blah).call
  end

  def test_raises_with_bang
    a = ActiveSupport::ConfigurationOptions.new
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

  def test_inspect
    a = ActiveSupport::ConfigurationOptions.new
    assert_equal "#<ActiveSupport::ConfigurationOptions {}>", a.inspect

    a.foo   = :bar
    a[:baz] = :quz

    assert_equal "#<ActiveSupport::ConfigurationOptions {:foo=>:bar, :baz=>:quz}>", a.inspect
  end

  def test_consume_values
    a = ActiveSupport::ConfigurationOptions.new
    a.foo = :bar
    a.foo = :plop
    assert_equal :plop, a.consume(:foo)
    assert_equal :plop, a.consume(:foo)

    assert_raises do
      a.foo = :bar
    end

    assert_raises do
      a[:foo] = :bar
    end
  end
end
