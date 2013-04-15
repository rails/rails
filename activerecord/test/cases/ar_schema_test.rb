require "cases/helper"

if ActiveRecord::Base.connection.supports_migrations?

  class ActiveRecordSchemaTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    def setup
      @connection = ActiveRecord::Base.connection
      ActiveRecord::SchemaMigration.drop_table
    end

    def teardown
      @connection.drop_table :fruits rescue nil
      ActiveRecord::SchemaMigration.delete_all rescue nil
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
      assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
      assert_equal 7, ActiveRecord::Migrator::current_version
    end

    def test_schema_raises_an_error_for_invalid_column_type
      assert_raise NoMethodError do
        ActiveRecord::Schema.define(:version => 8) do
          create_table :vegetables do |t|
            t.unknown :color
          end
        end
      end
    end

    def test_schema_subclass
      Class.new(ActiveRecord::Schema).define(:version => 9) do
        create_table :fruits
      end
      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
    end
  end
end
