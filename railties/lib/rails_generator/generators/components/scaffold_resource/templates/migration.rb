class <%= migration_name %> < ActiveRecord::Migration
  def self.up
    create_table :<%= table_name %> do |t|
      t.column :name,        :string
      t.column :description, :text
      t.column :created_at,  :datetime
    end
  end

  def self.down
    drop_table :<%= table_name %>
  end
end
