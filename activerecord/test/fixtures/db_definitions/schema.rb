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
end
