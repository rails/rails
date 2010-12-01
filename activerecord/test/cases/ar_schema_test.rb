require "cases/helper"

if ActiveRecord::Base.connection.supports_migrations?

  class ActiveRecordSchemaTest < ActiveRecord::TestCase
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
  end

  class ActiveRecordSchemaMigrationsTest < ActiveRecordSchemaTest
    def setup
      super
      @sm_table = ActiveRecord::Migrator.schema_migrations_table_name
      @connection.execute "DELETE FROM #{@connection.quote_table_name(@sm_table)}"
    end

    def test_migration_adds_row_to_migrations_table
      schema = ActiveRecord::Schema.new
      schema.migration("123001")
      schema.migration("123002", "add_magic_power_to_unicorns")
      rows = @connection.select_all("SELECT * FROM #{@connection.quote_table_name(@sm_table)}")
      assert_equal 2, rows.length

      assert_equal "123001", rows[0]["version"]
      assert_equal "", rows[0]["name"]
      assert_not_nil(rows[0]["migrated_at"])

      assert_equal "123002", rows[1]["version"]
      assert_equal "add_magic_power_to_unicorns", rows[1]["name"]
      assert_not_nil(rows[1]["migrated_at"])
    end

    def test_define_clears_schema_migrations
      assert_nothing_raised do
        ActiveRecord::Schema.define do
          migration("123001")
        end
        ActiveRecord::Schema.define do
          migration("123001")
        end
      end
    end
  end

end
