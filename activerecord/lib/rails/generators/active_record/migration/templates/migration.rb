class <%= migration_class_name %> < ActiveRecord::Migration
<%- if migration_action == 'add' -%>
  def change
<% attributes.each do |attribute| -%>
    add_column :<%= table_name %>, :<%= attribute.name %>, :<%= attribute.type %><%= attribute.inject_options %>
    <%- if attribute.has_index? -%>
    add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
    <%- end -%>
<%- end -%>
  end
<%- else -%>
  def up
<% attributes.each do |attribute| -%>
  <%- if migration_action -%>
    <%= migration_action %>_column :<%= table_name %>, :<%= attribute.name %><% if migration_action == 'add' %>, :<%= attribute.type %><%= attribute.inject_options %><% end %>
    <% if attribute.has_index? && migration_action == 'add' %>
    add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
    <% end -%>
  <%- end -%>
<%- end -%>
  end

  def down
<% attributes.reverse.each do |attribute| -%>
  <%- if migration_action -%>
    <%= migration_action == 'add' ? 'remove' : 'add' %>_column :<%= table_name %>, :<%= attribute.name %><% if migration_action == 'remove' %>, :<%= attribute.type %><%= attribute.inject_options %><% end %>
    <%- if attribute.has_index? && migration_action == 'remove' -%>
    add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
    <%- end -%>
  <%- end -%>
<%- end -%>
  end
<%- end -%>
end
