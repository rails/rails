ActiveRecord::Schema.define do
  create_table :table_with_autoincrement, :force => true do |t|
    t.column :name, :string
  end
end
