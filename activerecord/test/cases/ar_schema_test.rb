require "cases/helper"

if ActiveRecord::Base.connection.supports_migrations?

  class ActiveRecordSchemaTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      @connection.drop_table :fruits rescue nil
      @connection.drop_table :"_pre_fruits_suf_" rescue nil
      @connection.drop_table :"_pre_schema_migrations_suf_" rescue nil
    end

    def test_schema_define
      perform_schema_define!

      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
      assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
      assert_equal 7, ActiveRecord::Migrator::current_version
    end

    def test_schema_define_with_table_prefix_and_suffix
      ActiveRecord::Base.table_name_prefix = '_pre_'
      ActiveRecord::Base.table_name_suffix = '_suf_'

      perform_schema_define!

      assert_equal 7, ActiveRecord::Migrator::current_version
    ensure
      ActiveRecord::Base.table_name_prefix = ''
      ActiveRecord::Base.table_name_suffix = ''
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

  private

    def perform_schema_define!
      ActiveRecord::Schema.define(:version => 7) do
        create_table :fruits do |t|
          t.column :color, :string
          t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
          t.column :texture, :string
          t.column :flavor, :string
        end
      end
    end

end
