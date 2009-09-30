require 'test_helper'
require 'performance_test_help'

class <%= class_name %>Test < ActionController::PerformanceTest
  # Replace this with your real tests.
  def test_homepage
    get '/'
  end
end
