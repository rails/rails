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

    def test_collation
      assert_not_nil @connection.collation
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

    def test_reconnection_after_simulated_disconnection_with_verify
      assert @connection.active?
      original_connection_pid = @connection.query('select pg_backend_pid()')

      # Fail with bad connection on next query attempt.
      raw_connection = @connection.raw_connection
      raw_connection_class = class << raw_connection ; self ; end
      raw_connection_class.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def query_fake(*args)
          if !( @called ||= false )
            self.stubs(:status).returns(PGconn::CONNECTION_BAD)
            @called = true
            raise PGError
          else
            self.unstub(:status)
            query_unfake(*args)
          end
        end

        alias query_unfake query
        alias query        query_fake
      CODE

      begin
        @connection.verify!
        new_connection_pid = @connection.query('select pg_backend_pid()')
      ensure
        raw_connection_class.class_eval <<-CODE
          alias query query_unfake
          undef query_fake
        CODE
      end

      assert_not_equal original_connection_pid, new_connection_pid, "Should have a new underlying connection pid"
    end

    # Must have with_manual_interventions set to true for this
    # test to run.
    # When prompted, restart the PostgreSQL server with the
    # "-m fast" option or kill the individual connection assuming
    # you know the incantation to do that.
    # To restart PostgreSQL 9.1 on OS X, installed via MacPorts, ...
    # sudo su postgres -c "pg_ctl restart -D /opt/local/var/db/postgresql91/defaultdb/ -m fast"
    def test_reconnection_after_actual_disconnection_with_verify
      skip "with_manual_interventions is false in configuration" unless ARTest.config['with_manual_interventions']

      original_connection_pid = @connection.query('select pg_backend_pid()')

      # Sanity check.
      assert @connection.active?

      puts 'Kill the connection now (e.g. by restarting the PostgreSQL ' +
           'server with the "-m fast" option) and then press enter.'
      $stdin.gets

      @connection.verify!

      assert @connection.active?

      # If we get no exception here, then either we re-connected successfully, or
      # we never actually got disconnected.
      new_connection_pid = @connection.query('select pg_backend_pid()')

      assert_not_equal original_connection_pid, new_connection_pid,
        "umm -- looks like you didn't break the connection, because we're still " +
        "successfully querying with the same connection pid."

      # Repair all fixture connections so other tests won't break.
      @fixture_connections.each do |c|
        c.verify!
      end
    end

  end
end
