require 'test_helper'
require 'rails/performance_test_help'

class <%= class_name %>Test < ActionDispatch::PerformanceTest
  # Replace this with your real tests.
  def test_homepage
    get '/'
  end
end
