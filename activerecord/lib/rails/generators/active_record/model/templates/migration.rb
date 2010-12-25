class <%= migration_class_name %> < ActiveRecord::Migration
  def up
    create_table :<%= table_name %> do |t|
<% for attribute in attributes -%>
      t.<%= attribute.type %> :<%= attribute.name %>
<% end -%>
<% if options[:timestamps] %>
      t.timestamps
<% end -%>
    end

<% attributes.select {|attr| attr.reference? }.each do |attribute| -%>
    add_index :<%= table_name %>, :<%= attribute.name %>_id
<% end -%>
  end

  def down
    drop_table :<%= table_name %>
  end
end
