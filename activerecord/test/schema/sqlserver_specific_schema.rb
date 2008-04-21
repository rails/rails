ActiveRecord::Schema.define do
  create_table :table_with_real_columns, :force => true do |t|
    t.column :real_number, :real
  end
end