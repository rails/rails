ActiveRecord::Schema.define do
  suppress_messages do
    create_table :users, :primary_key_trigger => true, :force => true do |t|
      t.string :name, :limit => 255, :null => false
    end

    create_table :photos, :primary_key_trigger => true, :force => true do |t|
      t.integer :user_id
      t.integer :camera_id
    end

    create_table :developers, :primary_key_trigger => true, :force => true do |t|
      t.string :name, :limit => 255, :null => false
      t.integer :salary
      t.string :department, :limit => 255, :null => false
      t.timestamp :created_at, :null => false
    end

  end
end
