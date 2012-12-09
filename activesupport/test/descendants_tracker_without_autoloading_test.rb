require 'abstract_unit'
require 'active_support/descendants_tracker'
require 'descendants_tracker_test_cases'

class DescendantsTrackerWithoutAutoloadingTest < ActiveSupport::TestCase
  include DescendantsTrackerTestCases

  def test_clear_without_autoloaded_singleton_parent
    mark_as_autoloaded do
      parent_instance = Parent.new
      parent_instance.singleton_class.descendants   #adds singleton class in @@direct_descendants
      ActiveSupport::DescendantsTracker.clear   #clear is supposed to remove singleton class keys so GC can remove them.
      assert !ActiveSupport::DescendantsTracker.class_variable_get(:@@direct_descendants).keys.include?(parent_instance.singleton_class)
    end
  end

end
