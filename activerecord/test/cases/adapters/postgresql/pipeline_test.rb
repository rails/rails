# frozen_string_literal: true

require "cases/helper"
require "models/author"

module ActiveRecord
  class PostgresqlPipelineTest < ActiveRecord::PostgreSQLTestCase
    def setup
      super
      @connection = ActiveRecord::Base.lease_connection
      @connection.materialize_transactions
    end

    def teardown
      @connection.exit_pipeline_mode if @connection.pipeline_active?
      super
    end

    def test_pipeline_mode_lifecycle
      unless ENV["AR_POSTGRESQL_PIPELINE"]
        assert_not @connection.pipeline_active?, "Pipeline should not be active initially"
      end

      @connection.enter_pipeline_mode
      assert @connection.pipeline_active?, "Pipeline should be active after entering"

      @connection.exit_pipeline_mode
      assert_not @connection.pipeline_active?, "Pipeline should not be active after exiting"
    end

    def test_basic_pipeline_execution
      @connection.enter_pipeline_mode
      assert @connection.pipeline_active?

      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent2 = @connection.send(:internal_build_intent, "SELECT 2 AS n", "TEST")

      intent1.execute!
      intent2.execute!

      assert_not intent1.raw_result_available?
      assert_not intent2.raw_result_available?

      @connection.flush_pipeline

      assert intent1.raw_result_available?
      assert intent2.raw_result_available?

      result1 = @connection.send(:cast_result, intent1.raw_result)
      result2 = @connection.send(:cast_result, intent2.raw_result)

      assert_equal [[1]], result1.rows
      assert_equal [[2]], result2.rows

      @connection.exit_pipeline_mode
    end

    def test_queries_outside_pipeline_execute_immediately
      unless ENV["AR_POSTGRESQL_PIPELINE"]
        assert_not @connection.pipeline_active?
      end

      result = @connection.exec_query("SELECT 1 AS n")

      assert_equal [[1]], result.rows
    end

    def test_timezone_mismatch_resolved_before_pipeline_routing
      # Bind casting triggers timezone typemap update if ActiveRecord.default_timezone
      # has changed. This must happen before the pipeline routing decision, otherwise
      # the SET timezone query would execute mid-pipeline.
      original_mapped = @connection.instance_variable_get(:@mapped_default_timezone)

      # Force timezone mismatch to trigger update path
      other_timezone = ActiveRecord.default_timezone == :utc ? :local : :utc
      @connection.instance_variable_set(:@mapped_default_timezone, other_timezone)

      @connection.enter_pipeline_mode

      intent = @connection.send(:internal_build_intent, "SELECT $1::int", "TEST", [42])
      intent.execute!

      assert @connection.pipeline_active?, "Pipeline mode should remain active"

      @connection.exit_pipeline_mode
    ensure
      @connection.instance_variable_set(:@mapped_default_timezone, original_mapped)
    end

    def test_notification_exceptions_propagate_from_pipeline
      # Exceptions raised by notification subscribers should propagate directly,
      # not be caught and re-wrapped by pipeline error handling.
      original_error = StandardError.new("Subscriber error")
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { raise original_error }

      @connection.enter_pipeline_mode

      intent = @connection.send(:internal_build_intent, "SELECT 1", "TEST")
      intent.execute!

      actual_error = assert_raises(StandardError) do
        intent.cast_result
      end
      assert_equal original_error, actual_error
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      @connection.exit_pipeline_mode if @connection.pipeline_active?
    end

    def test_auto_flush_on_result_access
      @connection.enter_pipeline_mode

      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent2 = @connection.send(:internal_build_intent, "SELECT 2 AS n", "TEST")

      intent1.execute!
      intent2.execute!

      assert_not intent1.raw_result_available?
      assert_not intent2.raw_result_available?
      assert @connection.pipeline_active?

      # Accessing cast_result should auto-flush via ensure_result
      result1 = intent1.cast_result

      # Pipeline should still be active
      assert @connection.pipeline_active?

      # Both results should now be available (flush got both)
      assert intent1.raw_result_available?
      assert intent2.raw_result_available?

      assert_equal [[1]], result1.rows
      assert_equal [[2]], intent2.cast_result.rows

      @connection.exit_pipeline_mode
    end

    def test_syntax_error_in_pipelined_query
      @connection.enter_pipeline_mode

      intent = @connection.send(:internal_build_intent, "SELECT * FROM nonexistent_table_xyz", "TEST")
      intent.execute!

      assert_not intent.raw_result_available?
      assert @connection.pipeline_active?

      @connection.flush_pipeline

      assert intent.raw_result_available?

      error = assert_raises(ActiveRecord::StatementInvalid) do
        intent.cast_result
      end
      assert_match(/nonexistent_table_xyz/, error.message)

      @connection.exit_pipeline_mode
    end

    def test_error_in_one_query_aborts_pipeline
      @connection.enter_pipeline_mode

      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent2 = @connection.send(:internal_build_intent, "SELECT * FROM nonexistent_table_xyz", "TEST")
      intent3 = @connection.send(:internal_build_intent, "SELECT 2 AS n", "TEST")

      intent1.execute!
      intent2.execute!
      intent3.execute!

      @connection.flush_pipeline

      # First query should have succeeded
      assert intent1.raw_result_available?
      result1 = intent1.cast_result
      assert_equal [[1]], result1.rows

      # Second query should have error result
      assert intent2.raw_result_available?
      assert_raises(ActiveRecord::StatementInvalid) do
        intent2.cast_result
      end

      # Third query should have pipeline aborted result
      assert intent3.raw_result_available?
      assert_raises(ActiveRecord::StatementInvalid) do
        intent3.cast_result
      end

      @connection.exit_pipeline_mode
    end

    def test_error_deferred_until_result_access
      @connection.enter_pipeline_mode

      intent1 = @connection.send(:internal_build_intent, "SELECT * FROM nonexistent_table_xyz", "TEST")
      intent2 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")

      intent1.execute!
      intent2.execute!

      # Flush pipeline - should not raise here
      assert_nothing_raised do
        @connection.flush_pipeline
      end

      # Both should have results populated
      assert intent1.raw_result_available?
      assert intent2.raw_result_available?

      # Error is only raised when we try to access the failed result
      assert_raises(ActiveRecord::StatementInvalid) do
        intent1.cast_result
      end

      @connection.exit_pipeline_mode
    end

    def test_prepared_statement_not_pipelined
      @connection.enter_pipeline_mode

      # Queue a pipelined query
      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent1.execute!

      assert @connection.pipeline_active?
      assert_not intent1.raw_result_available?

      # Execute a prepared statement - should exit pipeline first
      intent2 = @connection.send(:internal_build_intent, "SELECT 2 AS n", "TEST", [], prepare: true)
      intent2.execute!

      # Pipeline should have been exited
      assert_not @connection.pipeline_active?

      # First intent should have been flushed
      assert intent1.raw_result_available?
      assert_equal [[1]], intent1.cast_result.rows

      # Second intent should have executed immediately
      assert intent2.raw_result_available?
      assert_equal [[2]], intent2.cast_result.rows
    end

    def test_preparable_arel_query_not_pipelined
      # When an intent is created with arel (not raw SQL) and prepare: nil,
      # preparability is determined later by compile_arel!. should_pipeline?
      # must check intent.prepare AFTER compile_arel! has run.
      @connection.enter_pipeline_mode

      # Queue a pipelined query
      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent1.execute!

      assert @connection.pipeline_active?
      assert_not intent1.raw_result_available?

      # Create intent from Relation arel with prepare: nil (like select_all does)
      intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
        adapter: @connection,
        arel: Author.where(id: 1).arel,
        name: "TEST",
        prepare: nil  # Determined by compile_arel!
      )
      intent2.execute!

      # Pipeline should have been exited because query is preparable
      assert_not @connection.pipeline_active?

      # First intent should have been flushed
      assert intent1.raw_result_available?
      assert_equal [[1]], intent1.cast_result.rows

      # Second intent should have executed immediately
      assert intent2.raw_result_available?
    end

    def test_multi_statement_sql_not_pipelined
      @connection.enter_pipeline_mode

      # Queue a pipelined query
      intent1 = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent1.execute!

      assert @connection.pipeline_active?
      assert_not intent1.raw_result_available?

      # Execute multi-statement SQL - should exit pipeline first
      intent2 = @connection.send(:internal_build_intent, "SELECT 1; SELECT 2", "TEST")
      intent2.execute!

      # Pipeline should have been exited
      assert_not @connection.pipeline_active?

      # First intent should have been flushed
      assert intent1.raw_result_available?
      assert_equal [[1]], intent1.cast_result.rows

      # Second intent should have executed immediately
      assert intent2.raw_result_available?
    end

    def test_concurrent_query_queueing
      @connection.enter_pipeline_mode

      threads = 4.times.map do |i|
        Thread.new do
          intent = @connection.send(:internal_build_intent, "SELECT #{i} AS n", "TEST")
          intent.execute!
          intent
        end
      end

      intents = threads.map(&:value)

      assert intents.all? { |intent| !intent.raw_result_available? }

      @connection.flush_pipeline

      assert intents.all?(&:raw_result_available?)

      results = intents.map { |intent| intent.cast_result.rows.first.first }
      assert_equal [0, 1, 2, 3].sort, results.sort

      @connection.exit_pipeline_mode
    end

    def test_concurrent_result_access
      @connection.enter_pipeline_mode

      intents = 4.times.map do |i|
        intent = @connection.send(:internal_build_intent, "SELECT #{i} AS n", "TEST")
        intent.execute!
        intent
      end

      threads = intents.map do |intent|
        Thread.new do
          intent.cast_result.rows.first.first
        end
      end

      results = threads.map(&:value)

      assert_equal [0, 1, 2, 3].sort, results.sort

      @connection.exit_pipeline_mode
    end

    def test_concurrent_flush_calls
      @connection.enter_pipeline_mode

      intents = 4.times.map do |i|
        intent = @connection.send(:internal_build_intent, "SELECT #{i} AS n", "TEST")
        intent.execute!
        intent
      end

      threads = 4.times.map do
        Thread.new do
          @connection.flush_pipeline
        end
      end

      threads.each(&:join)

      assert intents.all?(&:raw_result_available?)

      results = intents.map { |intent| intent.cast_result.rows.first.first }
      assert_equal [0, 1, 2, 3].sort, results.sort

      @connection.exit_pipeline_mode
    end

    def test_concurrent_mixed_operations
      @connection.enter_pipeline_mode

      intents = 8.times.map do |i|
        intent = @connection.send(:internal_build_intent, "SELECT #{i} AS n", "TEST")
        intent.execute!
        intent
      end

      threads = []

      threads += intents.each_slice(2).map do |slice|
        Thread.new do
          slice.map { |intent| intent.cast_result.rows.first.first }
        end
      end

      threads << Thread.new do
        sleep 0.001
        @connection.flush_pipeline
      end

      results = threads.flat_map(&:value).compact

      assert intents.all?(&:raw_result_available?)
      assert_equal 8, results.size
      assert_equal (0..7).to_a.sort, results.sort

      @connection.exit_pipeline_mode
    end

    def test_raw_connection_access_exits_pipeline
      @connection.enter_pipeline_mode

      intent = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent.execute!

      assert @connection.pipeline_active?
      assert_not intent.raw_result_available?

      # Access raw_connection - should exit pipeline and flush
      raw_conn = @connection.raw_connection
      assert_not_nil raw_conn

      assert_not @connection.pipeline_active?
      assert intent.raw_result_available?
      assert_equal [[1]], intent.cast_result.rows

      # Subsequent queries should execute immediately
      intent2 = @connection.send(:internal_build_intent, "SELECT 2 AS n", "TEST")
      intent2.execute!

      assert_not @connection.pipeline_active?
      assert intent2.raw_result_available?
      assert_equal [[2]], intent2.cast_result.rows
    end

    def test_auto_flush_on_checkin
      @connection.enter_pipeline_mode

      intent = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
      intent.execute!

      assert_not intent.raw_result_available?
      assert @connection.pipeline_active?

      # Return connection to pool (simulates what happens at end of request)
      @connection.send(:_run_checkin_callbacks) { }

      # Pipeline should be flushed and exited
      assert_not @connection.pipeline_active?
      assert intent.raw_result_available?

      result = @connection.send(:cast_result, intent.raw_result)
      assert_equal [[1]], result.rows
    end

    def test_concurrent_pipeline_mode_transitions
      threads = 10.times.map do
        Thread.new do
          5.times do
            @connection.enter_pipeline_mode
            Thread.pass
            @connection.exit_pipeline_mode
          end
        end
      end

      threads.each(&:join)

      assert_not @connection.pipeline_active?
    end

    def test_pipelined_query_instrumentation
      events = []
      callback = ->(name, start, finish, id, payload) { events << payload }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        @connection.enter_pipeline_mode

        intent = @connection.send(:internal_build_intent, "SELECT 1 AS n", "TEST")
        intent.execute!

        # No notification yet - query is queued but not flushed
        assert events.none? { |e| e[:sql] == "SELECT 1 AS n" }

        # Access result triggers flush and instrumentation
        intent.cast_result

        @connection.exit_pipeline_mode
      end

      event = events.find { |e| e[:sql] == "SELECT 1 AS n" }
      assert event, "Expected notification for pipelined query"
      assert_equal 1, event[:row_count]
    end

    def test_pipelined_sql_events_do_not_overlap_with_materialization
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
        events << event
      end

      @connection.transaction do
        @connection.select_all("SELECT 1 AS n", "TEST", [], pipeline: true).to_a
      end

      savepoint_event = events.find { |e| e.payload[:sql].start_with?("SAVEPOINT") }
      select_event = events.find { |e| e.payload[:sql] == "SELECT 1 AS n" }

      assert savepoint_event, "Expected SAVEPOINT event"
      assert select_event, "Expected SELECT event"

      # Transaction materialization (SAVEPOINT) must complete before the
      # pipelined query's own instrumentation event begins.
      assert_operator savepoint_event.end, :<=, select_event.time
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    def test_statement_pool_eviction_during_pipeline_mode
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_config = pool_config.configuration_hash.merge(statement_limit: 2)
      test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", test_config),
          :writing,
          :default
        )
      )

      begin
        conn = test_pool.checkout
        conn.materialize_transactions

        # Fill the statement cache to capacity
        conn.exec_query("SELECT 1", "SQL", [], prepare: true)
        conn.exec_query("SELECT 2", "SQL", [], prepare: true)

        conn.enter_pipeline_mode

        # Directly trigger statement pool eviction while in pipeline mode
        statements = conn.instance_variable_get(:@statements)
        first_key = statements.first[1]
        statements["new_statement"] = "a999"

        conn.exit_pipeline_mode
        prepared = conn.select_values("SELECT name FROM pg_prepared_statements")
        assert_not_includes prepared, first_key
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_prepare_statement_raises_in_pipeline_mode
      @connection.enter_pipeline_mode

      raw_conn = @connection.instance_variable_get(:@raw_connection)
      error = assert_raises(RuntimeError) do
        @connection.send(:prepare_statement, "SELECT 42", [], raw_conn)
      end
      assert_match(/pipeline mode does not support prepared statements/, error.message)

      @connection.exit_pipeline_mode
    end

    def test_pending_intents_cleared_on_connection_failure
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          pool_config,
          :writing,
          :default
        )
      )

      begin
        conn = test_pool.checkout
        conn.materialize_transactions
        pid = conn.select_value("SELECT pg_backend_pid()")

        conn.enter_pipeline_mode

        conn.send(:internal_build_intent, "SELECT 1", "TEST").execute!
        conn.send(:internal_build_intent, "SELECT 2", "TEST").execute!

        @connection.execute("SELECT pg_terminate_backend(#{pid})")

        # Drain pending results to make connection realize it's dead
        conn.instance_variable_get(:@raw_connection).tap do |raw_conn|
          raw_conn.pipeline_sync
          raw_conn.discard_results rescue nil
        end

        assert_raises(PG::ConnectionBad) do
          conn.exit_pipeline_mode
        end

        assert_empty conn.instance_variable_get(:@pending_intents)
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_multiple_retryable_pipelined_queries_all_recover
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          pool_config,
          :writing,
          :default
        )
      )

      begin
        conn = test_pool.checkout
        conn.materialize_transactions
        initial_pid = conn.select_value("SELECT pg_backend_pid()")

        conn.enter_pipeline_mode

        # Queue three retryable queries; the first is slow to ensure connection dies mid-flight
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n FROM pg_sleep(2)",
          name: "TEST",
          allow_retry: true
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: true
        )
        intent3 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 3 AS n",
          name: "TEST",
          allow_retry: true
        )

        intent1.execute!
        intent2.execute!
        intent3.execute!

        # Kill the connection while queries are running
        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # All three should succeed after retry
        assert_equal [[1]], intent1.cast_result.rows
        assert_equal [[2]], intent2.cast_result.rows
        assert_equal [[3]], intent3.cast_result.rows

        # Connection should have been replaced
        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_pipeline_failure_cascades_to_subsequent_queries
      # When a query fails in a pipeline, subsequent queries also fail.
      # This is the conservative default - we don't know if later queries
      # depended on earlier ones affecting server state.
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          pool_config,
          :writing,
          :default
        )
      )

      begin
        lock_holder = test_pool.checkout
        lock_holder.connect!
        conn = test_pool.checkout
        conn.connect!

        # Create a table and lock a row from another connection
        lock_holder.execute("CREATE TABLE IF NOT EXISTS pipeline_lock_test (id serial PRIMARY KEY)")
        lock_holder.execute("INSERT INTO pipeline_lock_test DEFAULT VALUES ON CONFLICT DO NOTHING")
        lock_holder.execute("BEGIN")
        lock_holder.execute("SELECT * FROM pipeline_lock_test FOR UPDATE")

        # Set lock_timeout before entering pipeline mode
        conn.execute("SET lock_timeout = '100ms'")
        conn.enter_pipeline_mode

        # First query will fail (lock timeout)
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT * FROM pipeline_lock_test FOR UPDATE",
          name: "TEST",
          allow_retry: false
        )
        # Second query will be aborted due to first query's failure
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: true
        )

        intent1.execute!
        intent2.execute!

        # First query fails
        assert_raises(ActiveRecord::LockWaitTimeout) do
          intent1.cast_result
        end

        # Second query also fails due to pipeline abort
        assert_raises(ActiveRecord::StatementInvalid) do
          intent2.cast_result
        end
      ensure
        lock_holder.execute("ROLLBACK") rescue nil
        test_pool.disconnect! rescue nil
      end
    end
  end

  class PostgresqlPipelineBatchSemanticsTest < ActiveRecord::PostgreSQLTestCase
    self.use_transactional_tests = false

    def setup
      super
      @connection = ActiveRecord::Base.lease_connection
      @connection.execute("CREATE TABLE IF NOT EXISTS pipeline_batch_test (id serial PRIMARY KEY, value text)")
      @connection.execute("TRUNCATE pipeline_batch_test")
    end

    def teardown
      @connection.exit_pipeline_mode if @connection.pipeline_active?
      @connection.execute("DROP TABLE IF EXISTS pipeline_batch_test")
      super
    end

    def test_pipeline_batch_forms_implicit_transaction
      @connection.enter_pipeline_mode

      intent1 = @connection.send(:internal_build_intent,
        "INSERT INTO pipeline_batch_test (value) VALUES ('first')", "TEST")
      intent1.execute!

      intent2 = @connection.send(:internal_build_intent,
        "INSERT INTO pipeline_batch_test (value) VALUES ('second')", "TEST")
      intent2.execute!

      intent3 = @connection.send(:internal_build_intent,
        "INSERT INTO nonexistent_table (value) VALUES ('fail')", "TEST")
      intent3.execute!

      @connection.flush_pipeline
      @connection.exit_pipeline_mode

      # The first two queries' results indicate success
      assert intent1.raw_result_available?
      assert_equal 1, intent1.raw_result.cmd_tuples

      # But the data was rolled back when the batch failed
      count = @connection.select_value("SELECT COUNT(*) FROM pipeline_batch_test")
      assert_equal 0, count
    end

    def test_pipeline_results_reflect_execution_not_commit
      @connection.enter_pipeline_mode

      intent1 = @connection.send(:internal_build_intent,
        "INSERT INTO pipeline_batch_test (value) VALUES ('tentative')", "TEST")
      intent1.execute!

      intent2 = @connection.send(:internal_build_intent,
        "SELECT * FROM nonexistent_table", "TEST")
      intent2.execute!

      @connection.flush_pipeline
      @connection.exit_pipeline_mode

      # intent1 reports successful execution (1 row affected)
      assert_equal 1, intent1.raw_result.cmd_tuples

      # But the data doesn't exist due to batch rollback
      count = @connection.select_value("SELECT COUNT(*) FROM pipeline_batch_test")
      assert_equal 0, count
    end

    def test_explicit_transaction_has_same_tentative_result_semantics
      @connection.transaction do
        @connection.enter_pipeline_mode

        intent1 = @connection.send(:internal_build_intent,
          "INSERT INTO pipeline_batch_test (value) VALUES ('in_transaction')", "TEST")
        intent1.execute!

        @connection.flush_pipeline

        assert_equal 1, intent1.raw_result.cmd_tuples

        @connection.exit_pipeline_mode

        raise ActiveRecord::Rollback
      end

      count = @connection.select_value("SELECT COUNT(*) FROM pipeline_batch_test")
      assert_equal 0, count
    end
  end
end
