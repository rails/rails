<% if mountable? -%>
<% unless options.skip_javascript -%>
//= link ./javascripts/<%= namespaced_name %>/application.js
<% end -%>
//= link ./stylesheets/<%= namespaced_name %>/application.css
<% end -%>
