class <%= migration_class_name %> < ActiveRecord::Migration
  def change
		add_index :<%= table_name %>, [:<%= attributes.map(&:name).join(", :") %>], name: 'index_<%= index_name %>'
  end
end
