ActiveRecord::Schema.define do

  create_table "taggings", :force => true do |t|
    t.column "tag_id", :integer
    t.column "taggable_type", :string
    t.column "taggable_id", :integer
  end

  create_table "tags", :force => true do |t|
    t.column "name", :string
    t.column :taggings_count, :integer, :default => 0
  end

  create_table "categorizations", :force => true do |t|
    t.column "category_id", :integer
    t.column "post_id", :integer
    t.column "author_id", :integer
  end

  add_column :posts, :taggings_count, :integer, :default => 0

end