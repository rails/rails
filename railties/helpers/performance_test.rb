ENV['RAILS_ENV'] ||= 'test'
require "#{File.dirname(__FILE__)}/../../config/environment"
require 'test/unit'
require 'action_controller/performance_test'

# Profiling results for each test method are written to tmp/performance.
class BrowsingTest < ActionController::PerformanceTest
  def test_homepage
    get '/'
  end
end
