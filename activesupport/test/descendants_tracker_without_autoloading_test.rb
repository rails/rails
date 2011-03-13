require 'abstract_unit'
require 'test/unit'
require 'active_support/descendants_tracker'
require 'descendants_tracker_test_cases'

class DescendantsTrackerWithoutAutoloadingTest < Test::Unit::TestCase
  include DescendantsTrackerTestCases
end