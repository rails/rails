class <%= migration_class_name %> < ActiveRecord::Migration
  def change
    create_table :<%= session_table_name %> do
      string :session_id, :null => false
      text :data
      timestamps
    end

    add_index :<%= session_table_name %>, :session_id
    add_index :<%= session_table_name %>, :updated_at
  end
end
