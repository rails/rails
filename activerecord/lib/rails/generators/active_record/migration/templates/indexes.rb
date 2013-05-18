class <%= migration_class_name %> < ActiveRecord::Migration
  def change
<%- if migration_action == 'add' -%>
  <%- attributes.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
<%- if migration_action == 'remove' -%>
  <%- attributes.each do |attribute| -%>
    remove_index :<%= table_name %>, column: :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
  end
end
