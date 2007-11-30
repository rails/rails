require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

class <%= class_name %>ControllerTest < ActionController::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
