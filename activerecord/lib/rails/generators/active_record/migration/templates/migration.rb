class <%= migration_class_name %> < ActiveRecord::Migration
  def up
<% attributes.each do |attribute| -%>
  <%- if migration_action -%>
    <%= migration_action %>_column :<%= table_name %>, :<%= attribute.name %><% if migration_action == 'add' %>, :<%= attribute.type %><% end %>
  <%- end -%>
<%- end -%>
  end

  def down
<% attributes.reverse.each do |attribute| -%>
  <%- if migration_action -%>
    <%= migration_action == 'add' ? 'remove' : 'add' %>_column :<%= table_name %>, :<%= attribute.name %><% if migration_action == 'remove' %>, :<%= attribute.type %><% end %>
  <%- end -%>
<%- end -%>
  end
end
