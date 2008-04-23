ActiveRecord::Schema.define do

  Course.connection.create_table :courses, :force => true do |t|
    t.column :name, :string, :null => false
  end
end
