<% if engine? -%>
require "<%= namespaced_name %>/engine"
<% else -%>
require "<%= namespaced_name %>/railtie"
<% end -%>

<%= wrap_in_modules "# Your code goes here..." %>
