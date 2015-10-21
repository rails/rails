
<% unless api? -%>
//= link_tree ../images
<% end -%>
<% unless options.skip_javascript -%>
//= link_directory ../javascripts .js
<% end -%>
//= link_directory ../stylesheets .css
<% if mountable? && !api? -%>
//= link <%= underscored_name %>_manifest.js
<% end -%>
