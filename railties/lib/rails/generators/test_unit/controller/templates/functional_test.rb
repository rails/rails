require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>ControllerTest < ActionDispatch::IntegrationTest
<% if mountable_engine? -%>
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
    get url_for(action: :<%= action %>)
    assert_response :success
  end

<% end -%>
<% end -%>
end
<% end -%>
