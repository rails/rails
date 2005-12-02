ActiveRecord::Schema.define do

  create_table "taggings", :force => true do |t|
    t.column "tag_id", :integer
    t.column "taggable_type", :string
    t.column "taggable_id", :integer
  end

  create_table "tags", :force => true do |t|
    t.column "name", :string
  end

end