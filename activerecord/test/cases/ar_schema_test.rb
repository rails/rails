require "cases/helper"

if ActiveRecord::Base.connection.supports_migrations?

  class ActiveRecordSchemaTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      @connection.drop_table :fruits rescue nil
      @connection.drop_table :"_p_fruits_s_" rescue nil
      @connection.drop_table :"_p_schema_migrations_s_" rescue nil
    end

    def test_schema_define
      perform_schema_define!

      assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
      assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
      assert_equal 7, ActiveRecord::Migrator::current_version
    end

    def test_schema_define_with_table_prefix_and_suffix
      # Use shorter prefix and suffix as in Oracle database identifier cannot be larger than 30 characters
      ActiveRecord::Base.table_name_prefix = '_p_'
      ActiveRecord::Base.table_name_suffix = '_s_'

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
