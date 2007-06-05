class <%= class_name %> < ActiveRecord::Migration
  def self.up
    create_table :<%= session_table_name %> do |t|
      t.string :session_id, :null => false
      t.text :data
      t.timestamps
    end

    add_index :<%= session_table_name %>, :session_id
    add_index :<%= session_table_name %>, :updated_at
  end

  def self.down
    drop_table :<%= session_table_name %>
  end
end
