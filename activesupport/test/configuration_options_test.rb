# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/ordered_options"

class ConfigurationOptionsTest < ActiveSupport::TestCase
  def setup
    @options = ActiveSupport::ConfigurationOptions.new("config.framework")
  end

  def test_usage
    assert_nil @options[:not_set]

    @options[:allow_concurrency] = true
    assert_equal 1, @options.size
    assert @options[:allow_concurrency]

    @options[:allow_concurrency] = false
    assert_equal 1, @options.size
    assert_not @options[:allow_concurrency]

    @options["else_where"] = 56
    assert_equal 2, @options.size
    assert_equal 56, @options[:else_where]
  end

  def test_looping
    @options[:allow_concurrency] = true
    @options["else_where"] = 56

    test = [[:allow_concurrency, true], [:else_where, 56]]

    @options.each_with_index do |(key, value), index|
      assert_equal test[index].first, key
      assert_equal test[index].last, value
    end
  end

  def test_string_dig
    @options[:test_key] = 56
    assert_equal 56, @options.test_key
    assert_equal 56, @options["test_key"]
    assert_equal 56, @options.dig(:test_key)
    assert_equal 56, @options.dig("test_key")
  end

  def test_method_access
    assert_nil @options.not_set

    @options.allow_concurrency = true
    assert_equal 1, @options.size
    assert @options.allow_concurrency

    @options.allow_concurrency = false
    assert_equal 1, @options.size
    assert_not @options.allow_concurrency

    @options.else_where = 56
    assert_equal 2, @options.size
    assert_equal 56, @options.else_where
  end

  def test_inheritable_options_continues_lookup_in_parent
    parent = @options
    parent[:foo] = true

    child = ActiveSupport::InheritableOptions.new(parent)
    assert child.foo
  end

  def test_inheritable_options_can_override_parent
    parent = @options
    parent[:foo] = :bar

    child = ActiveSupport::InheritableOptions.new(parent)
    child[:foo] = :baz

    assert_equal :baz, child.foo
  end

  def test_introspection
    assert_respond_to @options, :blah
    assert_respond_to @options, :blah=
    assert_equal 42, @options.method(:blah=).call(42)
    assert_equal 42, @options.method(:blah).call
  end

  def test_raises_with_bang
    @options[:foo] = :bar
    assert_respond_to @options, :foo!

    assert_nothing_raised { @options.foo! }
    assert_equal @options.foo, @options.foo!

    assert_raises(KeyError) do
      @options.foo = nil
      @options.foo!
    end
    assert_raises(KeyError) { @options.non_existing_key! }
  end

  def test_inheritable_options_with_bang
    @options[:foo] = :bar

    assert_nothing_raised { @options.foo! }
    assert_equal @options.foo, @options.foo!

    assert_raises(KeyError) do
      @options.foo = nil
      @options.foo!
    end
    assert_raises(KeyError) { @options.non_existing_key! }
  end

  def test_inspect
    assert_equal "#<ActiveSupport::ConfigurationOptions {}>", @options.inspect

    @options.foo   = :bar
    @options[:baz] = :quz

    assert_equal "#<ActiveSupport::ConfigurationOptions {:foo=>:bar, :baz=>:quz}>", @options.inspect
  end

  def test_consume_values
    @options.foo = :bar
    @options.foo = :plop
    assert_equal :plop, @options.consume(:foo)
    assert_equal :plop, @options.consume(:foo)

    error = assert_raises(KeyError) do
      @options.foo = :bar
    end
    assert_includes error.message, "config.framework.foo was already used."

    error = assert_raises do
      @options[:foo] = :bar
    end
    assert_includes error.message, "config.framework.foo was already used."
  end
end
