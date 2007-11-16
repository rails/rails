require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

class <%= controller_class_name %>ControllerTest < ActionController::TestCase
  tests <%= controller_class_name %>Controller

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
