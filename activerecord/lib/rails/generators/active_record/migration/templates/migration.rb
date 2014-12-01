class <%= migration_class_name %> < ActiveRecord::Migration
<%- if migration_action == 'add' -%>
  def change
<% attributes.each do |attribute| -%>
  <%- if attribute.reference? -%>
    add_reference :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_options %>
    <%- unless attribute.polymorphic? -%>
    add_foreign_key :<%= table_name %>, :<%= attribute.name.pluralize %>
    <%- end -%>
  <%- else -%>
    add_column :<%= table_name %>, :<%= attribute.name %>, :<%= attribute.type %><%= attribute.inject_options %>
    <%- if attribute.has_index? -%>
    add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
    <%- end -%>
  <%- end -%>
<%- end -%>
  end
<%- elsif migration_action == 'join' -%>
  def change
    create_join_table :<%= join_tables.first %>, :<%= join_tables.second %> do |t|
    <%- attributes.each do |attribute| -%>
      <%= '# ' unless attribute.has_index? -%>t.index <%= attribute.index_name %><%= attribute.inject_index_options %>
    <%- end -%>
    end
  end
<%- else -%>
  def change
<% attributes.each do |attribute| -%>
<%- if migration_action -%>
  <%- if attribute.reference? -%>
    remove_reference :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_options %>
    <%- unless attribute.polymorphic? -%>
    remove_foreign_key :<%= table_name %>, :<%= attribute.name.pluralize %>
    <%- end -%>
  <%- else -%>
    <%- if attribute.has_index? -%>
    remove_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
    <%- end -%>
    remove_column :<%= table_name %>, :<%= attribute.name %>, :<%= attribute.type %><%= attribute.inject_options %>
  <%- end -%>
<%- end -%>
<%- end -%>
  end
<%- end -%>
end
