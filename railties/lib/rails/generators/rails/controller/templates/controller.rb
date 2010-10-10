<% module_namespacing do -%>
class <%= class_name %>Controller < ApplicationController
<% for action in actions -%>
  def <%= action %>
  end

<% end -%>
end
<% end -%>
