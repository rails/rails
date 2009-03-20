ActiveRecord::Schema.define do
  create_table :topics, :force => true do |t|
    t.string   :title
    t.string   :author_name
    t.string   :author_email_address
    t.datetime :written_on
    t.time     :bonus_time
    t.date     :last_read
    t.text     :content
    t.boolean  :approved, :default => true
    t.integer  :replies_count, :default => 0
    t.integer  :parent_id
    t.string   :type
  end

  create_table :developers, :force => true do |t|
    t.string   :name
    t.integer  :salary, :default => 70000
    t.datetime :created_at
    t.datetime :updated_at
  end
end
