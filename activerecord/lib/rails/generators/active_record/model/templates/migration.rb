class <%= migration_class_name %> < ActiveRecord::Migration
  def change
    create_table :<%= table_name %> do |t|
<% attributes.each do |attribute| -%>
      t.<%= attribute.type %> :<%= attribute.name %><%= attribute.inject_options %>
<% end -%>
<% if options[:timestamps] %>
      t.timestamps
<% end -%>
    end
<% if options[:indexes] -%>
<% attributes.select {|attr| attr.reference? }.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %>_id<%= attribute.inject_index_options %>
<% end -%>
<% end -%>
<% attributes.select {|attr| attr.has_index? }.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %><%= attribute.inject_index_options %>
<% end -%>
  end
end
