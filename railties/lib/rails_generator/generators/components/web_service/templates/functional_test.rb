require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'
require '<%= file_path %>_controller'

class <%= class_name %>Controller; def rescue_action(e) raise e end; end

class <%= class_name %>ControllerApiTest < Test::Unit::TestCase
  def setup
    @controller = <%= class_name %>Controller.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
<% for method_name in args -%>

  def test_<%= method_name %>
    result = invoke :<%= method_name %>
    assert_equal nil, result
  end
<% end -%>
end
