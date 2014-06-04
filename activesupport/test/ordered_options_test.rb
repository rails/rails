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
      assert_equal test[index].first.to_s, key
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

  def test_inheritable_options_continues_lookup_in_parent
    parent = ActiveSupport::OrderedOptions.new
    parent[:foo] = true

    child = ActiveSupport::InheritableOptions.new(parent)
    assert child.foo
  end

  def test_inheritable_options_is_indifferent_to_parent_keys
    parent = { 'foo' => true, bar: true }

    child = ActiveSupport::InheritableOptions.new(parent)
    assert child.foo
    assert child.bar

    parent['baz'] = 'qux'

    # InheritableOptions retains a reference to the parent
    assert_equal 'qux', child.baz
  end

  def test_inheritable_options_wont_change_parent
    parent = { 'foo' => 'bar' }
    parent_copy = parent.dup

    child = ActiveSupport::InheritableOptions.new(parent)

    assert_equal 'bar', child.foo
    assert_equal parent_copy, parent
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
