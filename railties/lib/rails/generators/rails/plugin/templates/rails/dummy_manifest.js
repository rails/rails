<% unless api? -%>
//= link_tree ../images
<% end -%>
<% unless options.skip_javascript -%>
//= link application.js
<% end -%>
//= link application.css
<% if mountable? && !api? -%>
//= link <%= underscored_name %>_manifest.js
<% end -%>
