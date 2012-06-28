require "cases/helper"

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::TestCase
    class NonExistentTable < ActiveRecord::Base
    end

    def setup
      super
      @connection = ActiveRecord::Base.connection
      @connection.extend(LogIntercepter)
      @connection.intercepted = true
    end

    def teardown
      @connection.intercepted = false
      @connection.logged = []
    end

    def test_encoding
      assert_not_nil @connection.encoding
    end

    def test_collate
      assert_not_nil @connection.collate
    end

    def test_ctype
      assert_not_nil @connection.ctype
    end

    def test_default_client_min_messages
      assert_equal "warning", @connection.client_min_messages
    end

    # Ensure, we can set connection params using the example of Generic
    # Query Optimizer (geqo). It is 'on' per default.
    def test_connection_options
      params = ActiveRecord::Base.connection_config.dup
      params[:options] = "-c geqo=off"
      NonExistentTable.establish_connection(params)

      # Verify the connection param has been applied.
      expect = NonExistentTable.connection.query('show geqo').first.first
      assert_equal 'off', expect
    end

    def test_tables_logs_name
      @connection.tables('hello')
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_indexes_logs_name
      @connection.indexes('items', 'hello')
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_table_exists_logs_name
      @connection.table_exists?('items')
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_table_alias_length_logs_name
      @connection.instance_variable_set("@table_alias_length", nil)
      @connection.table_alias_length
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_current_database_logs_name
      @connection.current_database
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_encoding_logs_name
      @connection.encoding
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

    def test_schema_names_logs_name
      @connection.schema_names
      assert_equal 'SCHEMA', @connection.logged[0][1]
    end

  end
end
