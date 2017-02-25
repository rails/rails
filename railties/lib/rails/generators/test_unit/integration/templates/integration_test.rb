require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>Test < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end
end
<% end -%>
