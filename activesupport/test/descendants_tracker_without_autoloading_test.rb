require 'abstract_unit'
require 'active_support/descendants_tracker'
require 'descendants_tracker_test_cases'

class DescendantsTrackerWithoutAutoloadingTest < ActiveSupport::TestCase
  include DescendantsTrackerTestCases
end
