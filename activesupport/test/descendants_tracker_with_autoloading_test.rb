# frozen_string_literal: true

require "abstract_unit"
require "active_support/descendants_tracker"
require "active_support/dependencies"
require "descendants_tracker_test_cases"

class DescendantsTrackerWithAutoloadingTest < ActiveSupport::TestCase
  include DescendantsTrackerTestCases

  def setup
    ActiveSupport::DescendantsTracker.preloading_required = true
  end

  def test_clear_with_autoloaded_parent_children_and_grandchildren
    mark_as_autoloaded(*ALL) do
      ActiveSupport::DescendantsTracker.clear
      ALL.each do |k|
        assert_empty ActiveSupport::DescendantsTracker.descendants(k)
      end
    end
  end

  def test_clear_with_autoloaded_children_and_grandchildren
    mark_as_autoloaded Child1, Grandchild1, Grandchild2 do
      ActiveSupport::DescendantsTracker.clear
      assert_equal_sets [Child2], Parent.descendants
      assert_equal_sets [], Child2.descendants
    end
  end

  def test_clear_with_autoloaded_grandchildren
    mark_as_autoloaded Grandchild1, Grandchild2 do
      ActiveSupport::DescendantsTracker.clear
      assert_equal_sets [Child1, Child2], Parent.descendants
      assert_equal_sets [], Child1.descendants
      assert_equal_sets [], Child2.descendants
    end
  end

  def test_preload_descendants_is_called_once_if_autoloading_is_enabled
    refute_predicate Parent, :preload_descendants_called
    Parent.descendants
    assert_predicate Parent, :preload_descendants_called

    Parent.preload_descendants_called = false
    Parent.descendants
    refute_predicate Parent, :preload_descendants_called
  end

  def test_clear_reset_preload_descendants_memorization
    refute_predicate Parent, :preload_descendants_called
    Parent.descendants
    assert_predicate Parent, :preload_descendants_called

    Parent.preload_descendants_called = false
    ActiveSupport::DescendantsTracker.clear

    Parent.descendants
    assert_predicate Parent, :preload_descendants_called
  end
end
