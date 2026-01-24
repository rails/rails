# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::PostgreSQLTestCase
    include ConnectionHelper

    class NonExistentTable < ActiveRecord::Base
    end

    def setup
      super
      @subscriber = SQLSubscriber.new
      @connection = ActiveRecord::Base.lease_connection
      @connection.materialize_transactions
      @subscription = ActiveSupport::Notifications.subscribe("sql.active_record", @subscriber)
    end

    def teardown
      ActiveSupport::Notifications.unsubscribe(@subscription)
      super
    end

    def test_encoding
      assert_queries_count(1, include_schema: true) do
        assert_not_nil @connection.encoding
      end
    end

    def test_collation
      assert_queries_count(1, include_schema: true) do
        assert_not_nil @connection.collation
      end
    end

    def test_ctype
      assert_queries_count(1, include_schema: true) do
        assert_not_nil @connection.ctype
      end
    end

    def test_default_client_min_messages
      assert_equal "warning", @connection.client_min_messages
    end

    # Ensure, we can set connection params using the example of Generic
    # Query Optimizer (geqo). It is 'on' per default.
    def test_connection_options
      params = ActiveRecord::Base.connection_db_config.configuration_hash.dup
      params[:options] = "-c geqo=off"
      NonExistentTable.establish_connection(params)

      # Verify the connection param has been applied.
      actual = NonExistentTable.lease_connection.select_value("show geqo")
      assert_equal "off", actual
    ensure
      NonExistentTable.remove_connection
    end

    def test_reset
      @connection.query_command("ROLLBACK")
      @connection.query_command("SET geqo TO off")

      # Verify the setting has been applied.
      actual = @connection.select_value("show geqo")
      assert_equal "off", actual

      @connection.reset!

      # Verify the setting has been cleared.
      actual = @connection.select_value("show geqo")
      assert_equal "on", actual
    end

    def test_reset_with_transaction
      @connection.query_command("ROLLBACK")
      @connection.query_command("SET geqo TO off")

      # Verify the setting has been applied.
      actual = @connection.select_value("show geqo")
      assert_equal "off", actual

      @connection.query_command("BEGIN")
      @connection.reset!

      # Verify the setting has been cleared.
      actual = @connection.select_value("show geqo")
      assert_equal "on", actual
    end

    def test_tables_logs_name
      @connection.tables
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_indexes_logs_name
      @connection.indexes("items")
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_table_exists_logs_name
      @connection.table_exists?("items")
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_table_alias_length_logs_name
      @connection.instance_variable_set("@max_identifier_length", nil)
      @connection.table_alias_length
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_current_database_logs_name
      @connection.current_database
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_encoding_logs_name
      @connection.encoding
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    def test_schema_names_logs_name
      @connection.schema_names
      assert_equal "SCHEMA", @subscriber.logged[0][1]
    end

    if ActiveRecord::Base.lease_connection.prepared_statements
      def test_statement_key_is_logged
        bind = Relation::QueryAttribute.new(nil, 1, Type::Value.new)
        @connection.exec_query("SELECT $1::integer", "SQL", [bind], prepare: true)

        payload = @subscriber.payloads.find { |p| p[:sql] == "SELECT $1::integer" }
        name = payload[:statement_name]
        assert_not_nil name

        res = @connection.exec_query("EXPLAIN (FORMAT JSON) EXECUTE #{name}(1)")
        plan = res.column_types["QUERY PLAN"].deserialize res.rows.first.first
        assert_operator plan.length, :>, 0
      end
    end

    def test_prepare_false_with_binds
      @connection.stub(:prepared_statements, false) do
        bind = Relation::QueryAttribute.new(nil, 42, Type::Value.new)
        result = @connection.exec_query("SELECT $1::integer", "SQL", [bind], prepare: false)
        assert_equal [[42]], result.rows
      end
    end

    def test_reconnection_after_actual_disconnection_with_verify
      assert_predicate @connection, :active?
      cause_server_side_disconnect
      @connection.verify!
      assert_predicate @connection, :active?
    ensure
      # Repair all fixture connections so other tests won't break.
      @fixture_connection_pools.each { |p| p.lease_connection.verify! }
    end

    def test_set_session_variable_true
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: true }))
        set_true = ActiveRecord::Base.lease_connection.exec_query "SHOW DEBUG_PRINT_PLAN"
        assert_equal [["on"]], set_true.rows
      end
    end

    def test_set_session_variable_false
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: false }))
        set_false = ActiveRecord::Base.lease_connection.exec_query "SHOW DEBUG_PRINT_PLAN"
        assert_equal [["off"]], set_false.rows
      end
    end

    def test_set_session_variable_nil
      run_without_connection do |orig_connection|
        # This should be a no-op that does not raise an error
        assert_nothing_raised do
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: nil }))
        end
      end
    end

    def test_set_session_variable_default
      run_without_connection do |orig_connection|
        # This should execute a query that does not raise an error
        assert_nothing_raised do
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: :default }))
        end
      end
    end

    def test_set_session_timezone
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { timezone: "America/New_York" }))
        assert_equal "America/New_York", ActiveRecord::Base.lease_connection.select_value("SHOW TIME ZONE")
      end
    end

    def test_get_and_release_advisory_lock
      lock_id = 5295901941911233559
      list_advisory_locks = <<~SQL
        SELECT (classid::bigint << 32) | objid::bigint AS lock_id
        FROM pg_locks
        WHERE locktype = 'advisory'
      SQL

      got_lock = @connection.get_advisory_lock(lock_id)
      assert got_lock, "get_advisory_lock should have returned true but it didn't"

      advisory_locks = @connection.select_values(list_advisory_locks)
      assert_includes advisory_locks, lock_id,
        "expected to find an advisory lock with lock_id #{lock_id} but there wasn't one"

      released_lock = @connection.release_advisory_lock(lock_id)
      assert released_lock, "expected release_advisory_lock to return true but it didn't"

      advisory_locks = @connection.select_values(list_advisory_locks)
      assert_not_includes advisory_locks, lock_id,
        "expected to have released advisory lock with lock_id #{lock_id} but it was still held"
    end

    def test_release_non_existent_advisory_lock
      fake_lock_id = 2940075057017742022
      with_warning_suppression do
        released_non_existent_lock = @connection.release_advisory_lock(fake_lock_id)
        assert_equal false, released_non_existent_lock,
          "expected release_advisory_lock to return false when there was no lock to release"
      end
    end

    private
      def cause_server_side_disconnect
        unless @connection.instance_variable_get(:@raw_connection).transaction_status == ::PG::PQTRANS_INTRANS
          @connection.execute("begin")
        end
        @connection.execute("set idle_in_transaction_session_timeout = '10ms'")
        sleep 0.05
      end

      def with_warning_suppression
        log_level = @connection.client_min_messages
        @connection.client_min_messages = "error"
        yield
        @connection.client_min_messages = log_level
      end
  end
end
