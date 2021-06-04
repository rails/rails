# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/descendants_tracker"
require_relative "descendants_tracker_test_cases"

class DescendantsTrackerWithoutAutoloadingTest < ActiveSupport::TestCase
  include DescendantsTrackerTestCases

  # Regression test for #8422. https://github.com/rails/rails/issues/8442
  def test_clear_without_autoloaded_singleton_parent
    mark_as_autoloaded do
      parent_instance = Parent.new
      parent_instance.singleton_class.descendants
      ActiveSupport::DescendantsTracker.clear
      assert_not ActiveSupport::DescendantsTracker.class_variable_get(:@@direct_descendants).key?(parent_instance.singleton_class)
    end
  end
end
