require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>ControllerTest < ActionDispatch::IntegrationTest
<% if mountable_engine? -%>
  include Engine.routes.url_helpers

<% end -%>
<% if actions.empty? -%>
  # test "the truth" do
  #   assert true
  # end
<% else -%>
<% actions.each do |action| -%>
  test "should get <%= action %>" do
    get <%= url_helper_prefix %>_<%= action %>_url
    assert_response :success
  end

<% end -%>
<% end -%>
end
<% end -%>
