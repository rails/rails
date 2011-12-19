require 'test_helper'

<% module_namespacing do -%>
class <%= class_name %>Test < ActiveSupport::TestCase
<% if actions.empty? -%>
  #test "the truth" do
  #  assert true
  #end
<% else -%>
<% actions.each do |action| -%>
  test "<%= action %>" do
    assert true
  end
<% end -%>
<% end -%>
end
<% end -%>
