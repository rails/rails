require 'action_controller/integration'
require 'active_support/testing/performance'
require 'active_support/testing/default'

module ActionController
  # An integration test that runs a code profiler on your test methods.
  # Profiling output for combinations of each test method, measurement, and
  # output format are written to your tmp/performance directory.
  #
  # By default, process_time is measured and both flat and graph_html output
  # formats are written, so you'll have two output files per test method.
  class PerformanceTest < ActionController::IntegrationTest
    include ActiveSupport::Testing::Performance
    include ActiveSupport::Testing::Default
  end
end
