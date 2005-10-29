require 'abstract_unit'
require "#{File.dirname(__FILE__)}/../lib/active_record/schema"

if ActiveRecord::Base.connection.supports_migrations? 

  class ActiveRecordSchemaTest < Test::Unit::TestCase
    self.use_transactional_fixtures = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      @connection.drop_table :fruits rescue nil
    end

    def test_schema_define
      ActiveRecord::Schema.define(:version => 7) do
        create_table :fruits do |t|
          t.column :color, :string
          t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
          t.column :texture, :string
          t.column :flavor, :string
        end
      end

      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
      assert_nothing_raised { @connection.select_all "SELECT * FROM schema_info" }
      assert_equal 7, @connection.select_one("SELECT version FROM schema_info")['version'].to_i
    end
  end

end
