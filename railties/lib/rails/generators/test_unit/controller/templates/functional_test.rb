require 'test_helper'

class <%= class_name %>ControllerTest < ActionController::TestCase
<% if actions.empty? -%>
  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
<% else -%>
<% for action in actions -%>
  test "should get <%= action %>" do
    get :<%= action %>
    assert_response :success
  end

<% end -%>
<% end -%>
end
