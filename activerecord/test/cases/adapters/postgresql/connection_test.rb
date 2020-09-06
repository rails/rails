# frozen_string_literal: true

require 'cases/helper'
require 'support/connection_helper'

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::PostgreSQLTestCase
    include ConnectionHelper

    class NonExistentTable < ActiveRecord::Base
    end

    fixtures :comments

    def setup
      super
      @subscriber = SQLSubscriber.new
      @connection = ActiveRecord::Base.connection
      @connection.materialize_transactions
      @subscription = ActiveSupport::Notifications.subscribe('sql.active_record', @subscriber)
    end

    def teardown
      ActiveSupport::Notifications.unsubscribe(@subscription)
      super
    end

    def test_encoding
      assert_queries(1, ignore_none: true) do
        assert_not_nil @connection.encoding
      end
    end

    def test_collation
      assert_queries(1, ignore_none: true) do
        assert_not_nil @connection.collation
      end
    end

    def test_ctype
      assert_queries(1, ignore_none: true) do
        assert_not_nil @connection.ctype
      end
    end

    def test_default_client_min_messages
      assert_equal 'warning', @connection.client_min_messages
    end

    # Ensure, we can set connection params using the example of Generic
    # Query Optimizer (geqo). It is 'on' per default.
    def test_connection_options
      params = ActiveRecord::Base.connection_db_config.configuration_hash.dup
      params[:options] = '-c geqo=off'
      NonExistentTable.establish_connection(params)

      # Verify the connection param has been applied.
      expect = NonExistentTable.connection.query('show geqo').first.first
      assert_equal 'off', expect
    end

    def test_reset
      @connection.query('ROLLBACK')
      @connection.query('SET geqo TO off')

      # Verify the setting has been applied.
      expect = @connection.query('show geqo').first.first
      assert_equal 'off', expect

      @connection.reset!

      # Verify the setting has been cleared.
      expect = @connection.query('show geqo').first.first
      assert_equal 'on', expect
    end

    def test_reset_with_transaction
      @connection.query('ROLLBACK')
      @connection.query('SET geqo TO off')

      # Verify the setting has been applied.
      expect = @connection.query('show geqo').first.first
      assert_equal 'off', expect

      @connection.query('BEGIN')
      @connection.reset!

      # Verify the setting has been cleared.
      expect = @connection.query('show geqo').first.first
      assert_equal 'on', expect
    end

    def test_tables_logs_name
      @connection.tables
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_indexes_logs_name
      @connection.indexes('items')
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_table_exists_logs_name
      @connection.table_exists?('items')
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_table_alias_length_logs_name
      @connection.instance_variable_set('@max_identifier_length', nil)
      @connection.table_alias_length
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_current_database_logs_name
      @connection.current_database
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_encoding_logs_name
      @connection.encoding
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    def test_schema_names_logs_name
      @connection.schema_names
      assert_equal 'SCHEMA', @subscriber.logged[0][1]
    end

    if ActiveRecord::Base.connection.prepared_statements
      def test_statement_key_is_logged
        bind = Relation::QueryAttribute.new(nil, 1, Type::Value.new)
        @connection.exec_query('SELECT $1::integer', 'SQL', [bind], prepare: true)
        name = @subscriber.payloads.last[:statement_name]
        assert name
        res = @connection.exec_query("EXPLAIN (FORMAT JSON) EXECUTE #{name}(1)")
        plan = res.column_types['QUERY PLAN'].deserialize res.rows.first.first
        assert_operator plan.length, :>, 0
      end
    end

    def test_reconnection_after_actual_disconnection_with_verify
      original_connection_pid = @connection.query('select pg_backend_pid()')

      # Sanity check.
      assert_predicate @connection, :active?

      secondary_connection = ActiveRecord::Base.connection_pool.checkout
      secondary_connection.query("select pg_terminate_backend(#{original_connection_pid.first.first})")
      ActiveRecord::Base.connection_pool.checkin(secondary_connection)

      @connection.verify!

      assert_predicate @connection, :active?

      # If we get no exception here, then either we re-connected successfully, or
      # we never actually got disconnected.
      new_connection_pid = @connection.query('select pg_backend_pid()')

      assert_not_equal original_connection_pid, new_connection_pid,
        "umm -- looks like you didn't break the connection, because we're still " \
        'successfully querying with the same connection pid.'
    ensure
      # Repair all fixture connections so other tests won't break.
      @fixture_connections.each(&:verify!)
    end

    def test_set_session_variable_true
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: true }))
        set_true = ActiveRecord::Base.connection.exec_query 'SHOW DEBUG_PRINT_PLAN'
        assert_equal set_true.rows, [['on']]
      end
    end

    def test_set_session_variable_false
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: false }))
        set_false = ActiveRecord::Base.connection.exec_query 'SHOW DEBUG_PRINT_PLAN'
        assert_equal set_false.rows, [['off']]
      end
    end

    def test_set_session_variable_nil
      run_without_connection do |orig_connection|
        # This should be a no-op that does not raise an error
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: nil }))
      end
    end

    def test_set_session_variable_default
      run_without_connection do |orig_connection|
        # This should execute a query that does not raise an error
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { debug_print_plan: :default }))
      end
    end

    def test_set_session_timezone
      run_without_connection do |orig_connection|
        ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { timezone: 'America/New_York' }))
        assert_equal 'America/New_York', ActiveRecord::Base.connection.query_value('SHOW TIME ZONE')
      end
    end

    def test_get_and_release_advisory_lock
      lock_id = 5295901941911233559
      list_advisory_locks = <<~SQL
        SELECT locktype,
              (classid::bigint << 32) | objid::bigint AS lock_id
        FROM pg_locks
        WHERE locktype = 'advisory'
      SQL

      got_lock = @connection.get_advisory_lock(lock_id)
      assert got_lock, "get_advisory_lock should have returned true but it didn't"

      advisory_lock = @connection.query(list_advisory_locks).find { |l| l[1] == lock_id }
      assert advisory_lock,
        "expected to find an advisory lock with lock_id #{lock_id} but there wasn't one"

      released_lock = @connection.release_advisory_lock(lock_id)
      assert released_lock, "expected release_advisory_lock to return true but it didn't"

      advisory_locks = @connection.query(list_advisory_locks).select { |l| l[1] == lock_id }
      assert_empty advisory_locks,
        "expected to have released advisory lock with lock_id #{lock_id} but it was still held"
    end

    def test_release_non_existent_advisory_lock
      fake_lock_id = 2940075057017742022
      with_warning_suppression do
        released_non_existent_lock = @connection.release_advisory_lock(fake_lock_id)
        assert_equal released_non_existent_lock, false,
          'expected release_advisory_lock to return false when there was no lock to release'
      end
    end

    def test_supports_ranges_is_deprecated
      assert_deprecated { @connection.supports_ranges? }
    end

    private
      def with_warning_suppression
        log_level = @connection.client_min_messages
        @connection.client_min_messages = 'error'
        yield
        @connection.client_min_messages = log_level
      end
  end
end
