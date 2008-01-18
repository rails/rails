ActiveRecord::Schema.define do

  # adapter name is checked because we are under a transition of
  # moving the sql files under activerecord/test/fixtures/db_definitions
  # to this file, schema.rb.
  if adapter_name == "MySQL"
    Course.connection.create_table :courses, :force => true do |t|
      t.column :name, :string, :null => false
    end
  end
end
