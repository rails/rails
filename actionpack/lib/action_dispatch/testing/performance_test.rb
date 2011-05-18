require 'active_support/testing/performance'

module ActionDispatch
  # An integration test that runs a code profiler on your test methods.
  # Profiling output for combinations of each test method, measurement, and
  # output format are written to your tmp/performance directory.
  class PerformanceTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::Performance
  end
end
