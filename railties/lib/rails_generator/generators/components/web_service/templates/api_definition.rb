class <%= class_name %>Api < ActionWebService::API::Base
<% for method_name in args -%>
  api_method :<%= method_name %>
<% end -%>
end
