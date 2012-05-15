require 'active_support/testing/performance'
require 'action_view/helpers/number_helper'

ActiveSupport::Testing::Performance::Metrics::Amount.formatter = Proc.new() do |measurement|
  include ActionView::Helpers::NumberHelper
  number_with_delimiter(measurement.floor)
end

ActiveSupport::Testing::Performance::Metrics::DigitalInformationUnit.formatter = Proc.new() do |measurement|
  include ActionView::Helpers::NumberHelper
  number_to_human_size(measurement, :precision => 2)
end

module ActionDispatch
  # An integration test that runs a code profiler on your test methods.
  # Profiling output for combinations of each test method, measurement, and
  # output format are written to your tmp/performance directory.
  class PerformanceTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::Performance
  end
end
