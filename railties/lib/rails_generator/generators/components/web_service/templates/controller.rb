class <%= class_name %>Controller < ApplicationController
  wsdl_service_name '<%= class_name %>'
<% for method_name in args -%>

  def <%= method_name %>
  end
<% end -%>
end
