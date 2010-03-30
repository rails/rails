require 'active_support/testing/performance'
require 'active_support/testing/default'

begin
  module ActionDispatch
    # An integration test that runs a code profiler on your test methods.
    # Profiling output for combinations of each test method, measurement, and
    # output format are written to your tmp/performance directory.
    #
    # By default, process_time is measured and both flat and graph_html output
    # formats are written, so you'll have two output files per test method.
    class PerformanceTest < ActionDispatch::IntegrationTest
      include ActiveSupport::Testing::Performance
      include ActiveSupport::Testing::Default
    end
  end
rescue NameError
  $stderr.puts "Specify ruby-prof as application's dependency in Gemfile to run benchmarks."
end