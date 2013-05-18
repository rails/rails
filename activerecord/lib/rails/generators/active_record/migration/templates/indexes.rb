class <%= migration_class_name %> < ActiveRecord::Migration
  def change
<%- if migration_action == 'add' -%>
<%- if migration_target == 'index_combined' -%>
  <%- if attributes.any? -%>
	add_index :<%= table_name %>, [:<%= attributes.map(&:name).join(", :") %>]<%= attributes.map(&:inject_index_options).select(&:present?).first %>
  <%- end -%>
<%- else -%>
  <%- attributes.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
<%- end -%>
<%- if migration_action == 'remove' -%>
<%- if migration_target == 'index_combined' -%>
  <%- if attributes.any? -%>
  remove_index :<%= table_name %>, column: [:<%= attributes.map(&:name).join(", :") %>]<%= attributes.map(&:inject_index_options).select(&:present?).first %>
  <%- end -%>
<%- else -%>
  <%- attributes.each do |attribute| -%>
    remove_index :<%= table_name %>, column: :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
<%- end -%>
  end
end
