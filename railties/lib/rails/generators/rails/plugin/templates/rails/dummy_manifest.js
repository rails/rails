
<% unless api? -%>
//= link_tree ./images
<% end -%>
<% unless options.skip_javascript -%>
//= link ./javascripts/application.js
<% end -%>
//= link ./stylesheets/application.css
<% if mountable? && !api? -%>
//= link <%= underscored_name %>_manifest.js
<% end -%>
