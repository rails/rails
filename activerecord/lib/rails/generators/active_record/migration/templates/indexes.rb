class <%= migration_class_name %> < ActiveRecord::Migration
  def change
<%- if migration_action == 'add' -%>
<%- if migration_target == 'index_combined' -%>
  <%- attributes.each_with_index do |attribute, index| -%>
    <%- next unless index % 2 == 0 -%>
	add_index :<%= table_name %>, [:<%= attributes.at(index).name %>, :<%= attributes.at(index+1).name %>]<%= attributes.map(&:inject_index_options).select(&:present?).first %>
  <%- end -%>
<%- else -%>
  <%- attributes.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
<%- end -%>
<%- if migration_action == 'remove' -%>
<%- if migration_target == 'index_combined' -%>
  <%- attributes.each_with_index do |attribute, index| -%>
    <%- next unless index % 2 == 0 -%>
    remove_index :<%= table_name %>, column: [:<%= attributes.at(index).name %>, :<%= attributes.at(index+1).name %>]<%= attributes.map(&:inject_index_options).select(&:present?).first %>
  <%- end -%>
<%- else -%>
  <%- attributes.each do |attribute| -%>
    remove_index :<%= table_name %>, column: :<%= attribute.name %><%= attribute.inject_index_options %>
  <%- end -%>
<%- end -%>
<%- end -%>
  end
end
