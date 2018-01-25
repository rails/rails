# frozen_string_literal: true

require "set"

module DescendantsTrackerTestCases
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
    assert_equal_sets [Child1, Grandchild1, Grandchild2, Child2], Parent.descendants
    assert_equal_sets [Grandchild1, Grandchild2], Child1.descendants
    assert_equal_sets [], Child2.descendants
  end

  def test_direct_descendants
    assert_equal_sets [Child1, Child2], Parent.direct_descendants
    assert_equal_sets [Grandchild1, Grandchild2], Child1.direct_descendants
    assert_equal_sets [], Child2.direct_descendants
  end

  def test_clear
    mark_as_autoloaded(*ALL) do
      ActiveSupport::DescendantsTracker.clear
      ALL.each do |k|
        assert_predicate ActiveSupport::DescendantsTracker.descendants(k), :empty?
      end
    end
  end

  private

    def assert_equal_sets(expected, actual)
      assert_equal Set.new(expected), Set.new(actual)
    end

    def mark_as_autoloaded(*klasses)
      # If ActiveSupport::Dependencies is not loaded, forget about autoloading.
      # This allows using AS::DescendantsTracker without AS::Dependencies.
      if defined? ActiveSupport::Dependencies
        old_autoloaded = ActiveSupport::Dependencies.autoloaded_constants.dup
        ActiveSupport::Dependencies.autoloaded_constants = klasses.map(&:name)
      end

      old_descendants = ActiveSupport::DescendantsTracker.class_eval("@@direct_descendants").dup
      old_descendants.each { |k, v| old_descendants[k] = v.dup }

      yield
    ensure
      ActiveSupport::Dependencies.autoloaded_constants = old_autoloaded if defined? ActiveSupport::Dependencies
      ActiveSupport::DescendantsTracker.class_eval("@@direct_descendants").replace(old_descendants)
    end
end
