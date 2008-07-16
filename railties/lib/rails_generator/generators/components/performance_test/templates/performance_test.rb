require 'performance/test_helper'

class <%= class_name %>Test < ActionController::PerformanceTest
  # Replace this with your real tests.
  def test_homepage
    get '/'
  end
end
