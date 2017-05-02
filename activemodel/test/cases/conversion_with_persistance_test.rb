require 'cases/helper'
require 'active_record'

class ConversionWithPersistanceTest < ActiveModel::TestCase
  setup do
    @klass = Class.new(ActiveRecord::Base) do
      ActiveRecord::Base.establish_connection({ adapter: "sqlite3", database: "testing" })
      ActiveRecord::Base.connection.create_table(:conversion_with_persistances) do |t|
        t.string :name
      end
      self.table_name  = "conversion_with_persistances"
      self.primary_key = "name"
    end
  end

  teardown do
    ActiveRecord::Base.connection.drop_table :conversion_with_persistances
  end

  test "to_key implementation for new ActiveRecord::Base inherited class object" do
    assert_equal ['Aditya'], @klass.new(name: 'Aditya').to_key
  end

  test "to_key implementation for ActiveRecord::Base persisted class object" do
    assert_equal ['Aditya'], @klass.create(name: 'Aditya').to_key
  end
end