require "active_support/test_case"

module ActiveJob
  class TestCase < ActiveSupport::TestCase
    include ActiveJob::TestHelper
  end
end
