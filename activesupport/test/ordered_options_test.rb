require 'abstract_unit'
require 'active_support/ordered_options'

class OrderedOptionsTest < ActiveSupport::TestCase
  def test_usage
    a = ActiveSupport::OrderedOptions.new

    assert_nil a[:not_set]

    a[:allow_concurrency] = true
    assert_equal 1, a.size
    assert a[:allow_concurrency]

    a[:allow_concurrency] = false
    assert_equal 1, a.size
    assert !a[:allow_concurrency]

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

  def test_method_access
    a = ActiveSupport::OrderedOptions.new

    assert_nil a.not_set

    a.allow_concurrency = true
    assert_equal 1, a.size
    assert a.allow_concurrency

    a.allow_concurrency = false
    assert_equal 1, a.size
    assert !a.allow_concurrency

    a.else_where = 56
    assert_equal 2, a.size
    assert_equal 56, a.else_where
  end

  def test_caching_of_writer_method
    a = ActiveSupport::OrderedOptions.new

    original_owner = a.method(:allow_concurrency=).owner
    assert_equal ActiveSupport::OrderedOptions, original_owner

    a.allow_concurrency = true
    current_owner = a.method(:allow_concurrency=).owner
    assert_not_equal original_owner, current_owner
    assert_not_equal ActiveSupport::OrderedOptions, current_owner
  end

  def test_caching_of_reader_method
    a = ActiveSupport::OrderedOptions.new

    original_owner = a.method(:allow_concurrency).owner
    assert_equal ActiveSupport::OrderedOptions, original_owner

    a.allow_concurrency = true
    assert a.allow_concurrency
    current_owner = a.method(:allow_concurrency).owner
    assert_not_equal original_owner, current_owner
    assert_not_equal ActiveSupport::OrderedOptions, current_owner
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
    assert a.respond_to?(:blah)
    assert a.respond_to?(:blah=)
    assert_equal 42, a.method(:blah=).call(42)
    assert_equal 42, a.method(:blah).call
  end
end
