require File.dirname(__FILE__) + '/../test_helper'
require '<%= file_name %>_controller'

# Re-raise errors caught by the controller.
class <%= full_class_name %>; def rescue_action(e) raise e end; end

class <%= full_class_name %>Test < Test::Unit::TestCase
  def setup
    @controller = <%= full_class_name %>.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
