require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>ControllerTest < ActionController::TestCase
<% if defined?(ENGINE_ROOT) -%>
  setup do
    @routes = Engine.routes
  end

<% end -%>
<% if actions.empty? -%>
  # test "the truth" do
  #   assert true
  # end
<% else -%>
<% actions.each do |action| -%>
  test "should get <%= action %>" do
    get :<%= action %>
    assert_response :success
  end

<% end -%>
<% end -%>
end
<% end -%>
