ActiveRecord::Schema.define do
  create_table :topics, :force => true do |t|
    t.string  :title
    t.string  :author_name
    t.text    :content
    t.boolean :approved, :default => true
    t.string  :type
  end

  create_table :developers, :force => true do |t|
    t.string  :name
    t.float   :salary
  end
end
