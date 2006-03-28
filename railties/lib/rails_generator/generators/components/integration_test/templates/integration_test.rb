require "#{File.dirname(__FILE__)}<%= '/..' * class_nesting_depth %>/../test_helper"

class <%= class_name %>Test < ActionController::IntegrationTest
  # fixtures :your, :models

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
