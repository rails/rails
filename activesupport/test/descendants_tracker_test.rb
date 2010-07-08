require 'abstract_unit'
require 'test/unit'
require 'active_support'
require 'active_support/core_ext/hash/slice'

class DescendantsTrackerTest < Test::Unit::TestCase
  class Parent
    extend ActiveSupport::DescendantsTracker
  end

  class Child1 < Parent
  end

  class Child2 < Parent
  end

  class Grandchild1 < Child1
  end

  class Grandchild2 < Child1
  end

  ALL = [Parent, Child1, Child2, Grandchild1, Grandchild2]

  def test_descendants
    assert_equal [Child1, Grandchild1, Grandchild2, Child2], Parent.descendants
    assert_equal [Grandchild1, Grandchild2], Child1.descendants
    assert_equal [], Child2.descendants
  end

  def test_direct_descendants
    assert_equal [Child1, Child2], Parent.direct_descendants
    assert_equal [Grandchild1, Grandchild2], Child1.direct_descendants
    assert_equal [], Child2.direct_descendants
  end

  def test_clear_with_autoloaded_parent_children_and_granchildren
    mark_as_autoloaded(*ALL) do
      ActiveSupport::DescendantsTracker.clear
      ALL.each do |k|
        assert ActiveSupport::DescendantsTracker.descendants(k).empty?
      end
    end
  end

  def test_clear_with_autoloaded_children_and_granchildren
    mark_as_autoloaded Child1, Grandchild1, Grandchild2 do
      ActiveSupport::DescendantsTracker.clear
      assert_equal [Child2], Parent.descendants
      assert_equal [], Child2.descendants
    end
  end

  def test_clear_with_autoloaded_granchildren
    mark_as_autoloaded Grandchild1, Grandchild2 do
      ActiveSupport::DescendantsTracker.clear
      assert_equal [Child1, Child2], Parent.descendants
      assert_equal [], Child1.descendants
      assert_equal [], Child2.descendants
    end
  end

  protected

  def mark_as_autoloaded(*klasses)
    old_autoloaded = ActiveSupport::Dependencies.autoloaded_constants.dup
    ActiveSupport::Dependencies.autoloaded_constants = klasses.map(&:name)

    old_descendants = ActiveSupport::DescendantsTracker.class_eval("@@direct_descendants").dup
    old_descendants.each { |k, v| old_descendants[k] = v.dup }

    yield
  ensure
    ActiveSupport::Dependencies.autoloaded_constants = old_autoloaded
    ActiveSupport::DescendantsTracker.class_eval("@@direct_descendants").replace(old_descendants)
  end
end