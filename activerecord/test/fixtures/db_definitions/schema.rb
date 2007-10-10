ActiveRecord::Schema.define do

  # For Firebird, set the sequence values 10000 when create_table is called;
  # this prevents primary key collisions between "normally" created records
  # and fixture-based (YAML) records.
  if adapter_name == "Firebird"
    def create_table(*args, &block)
      ActiveRecord::Base.connection.create_table(*args, &block)
      ActiveRecord::Base.connection.execute "SET GENERATOR #{args.first}_seq TO 10000"
    end
  end

  create_table :taggings, :force => true do |t|
    t.column :tag_id, :integer
    t.column :super_tag_id, :integer
    t.column :taggable_type, :string
    t.column :taggable_id, :integer
  end

  create_table :tags, :force => true do |t|
    t.column :name, :string
    t.column :taggings_count, :integer, :default => 0
  end

  create_table :categorizations, :force => true do |t|
    t.column :category_id, :integer
    t.column :post_id, :integer
    t.column :author_id, :integer
  end

  add_column :posts, :taggings_count, :integer, :default => 0
  add_column :authors, :author_address_id, :integer

  create_table :author_addresses, :force => true do |t|
    t.column :author_address_id, :integer
  end

  create_table :author_favorites, :force => true do |t|
    t.column :author_id, :integer
    t.column :favorite_author_id, :integer
  end

  create_table :vertices, :force => true do |t|
    t.column :label, :string
  end

  create_table :edges, :force => true do |t|
    t.column :source_id, :integer, :null => false
    t.column :sink_id,   :integer, :null => false
  end
  add_index :edges, [:source_id, :sink_id], :unique => true, :name => 'unique_edge_index'

  create_table :lock_without_defaults, :force => true do |t|
    t.column :lock_version, :integer
  end
  
  create_table :lock_without_defaults_cust, :force => true do |t|
    t.column :custom_lock_version, :integer
  end
  
  create_table :audit_logs, :force => true do |t|
    t.column :message, :string, :null=>false
    t.column :developer_id, :integer, :null=>false
  end
end
