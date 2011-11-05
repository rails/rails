class <%= migration_class_name %> < ActiveRecord::Migration
  def change
    create_table :<%= table_name %> do
<% attributes.each do |attribute| -%>
      <%= attribute.type %> :<%= attribute.name %>
<% end -%>
<% if options[:timestamps] %>
      timestamps
<% end -%>
    end
<% if options[:indexes] -%>
<% attributes.select {|attr| attr.reference? }.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %>_id
<% end -%>
<% end -%>
  end
end
