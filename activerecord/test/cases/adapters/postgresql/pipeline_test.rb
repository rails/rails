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

      # Third query was server-aborted (never ran). It's resettable, so
      # accessing its result triggers on-demand re-execution. Inside the
      # fixture transaction, the transaction is in a failed state, so the
      # server rejects the re-execution attempt.
      assert intent3.raw_result_available?
      assert_equal :server_aborted, intent3.not_run_reason
      error = assert_raises(ActiveRecord::StatementInvalid) do
        intent3.cast_result
      end
      assert_match(/current transaction is aborted/, error.message)

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

        # exit_pipeline_mode flushes the pipeline, discovers the FATAL
        # error, reconnects, replays, and clears pending intents.
        conn.exit_pipeline_mode

        assert_empty conn.instance_variable_get(:@pending_intents)
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_pipelined_query_with_allow_retry_recovers_from_connection_death
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

        # Queue a slow query so it's still in-flight when we kill the connection
        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n FROM pg_sleep(2)",
          name: "TEST",
          allow_retry: true
        )
        intent.execute!

        assert conn.pipeline_active?
        assert_not intent.raw_result_available?

        # Kill the connection while the query is running
        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # Accessing the result should trigger flush, hit error, retry with reconnect, and succeed
        result = intent.cast_result

        assert_equal [[1]], result.rows

        # Connection should have been replaced
        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_pipelined_query_without_allow_retry_fails_on_connection_death
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

        # Queue a slow non-retryable query so it's still in-flight when we kill the connection
        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n FROM pg_sleep(2)",
          name: "TEST",
          allow_retry: false
        )
        intent.execute!

        # Kill the connection while the query is running
        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # Should fail without retry
        assert_raises(ActiveRecord::ConnectionFailed) do
          intent.cast_result
        end
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

    def test_transparent_replay_preserves_query_order
      # Replay must preserve the original pipeline order, otherwise
      # dependent queries (where a later query relies on side effects
      # of an earlier one) will fail.
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

        # These queries have a dependency: the INSERT references the
        # temp table created by the first query. If replay reorders
        # them, the INSERT will fail with "relation does not exist".
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "CREATE TEMP TABLE pipeline_order_test (val int) ON COMMIT DROP",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "INSERT INTO pipeline_order_test VALUES (42)",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent3 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT val FROM pipeline_order_test",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )

        intent1.execute!
        intent2.execute!
        intent3.execute!

        # Kill the connection - all three queries are replayed as a batch
        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        intent1.affected_rows
        intent2.affected_rows
        assert_equal [[42]], intent3.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_pipeline_aborted_intent_reexecutes_despite_allow_retry_false
      # When the server sends PGRES_PIPELINE_ABORTED, we trust it: the
      # query was definitively not executed. Re-execution via the not_run
      # path is safe regardless of allow_retry.
      #
      # This is distinct from the abandon path (socket close, no server
      # response) where synced non-retryable intents get ConnectionFailed
      # because fate is unknown. See test_synced_non_retryable_intent_blocks_replay.
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
          allow_retry: false
        )

        intent1.execute!
        intent2.execute!

        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # intent1 retries via ensure_result (retryable connection error)
        assert_equal [[1]], intent1.cast_result.rows

        # intent2 got PIPELINE_ABORTED - the server confirms it was not
        # executed. Re-executes on demand despite allow_retry: false.
        assert_equal [[2]], intent2.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_successful_non_retryable_intent_does_not_block_batch_replay
      # When a fast query succeeds and a slow query gets AdminShutdown,
      # the successful intent's allow_retry: false should not prevent
      # batch replay of the failed retryable intent. The replay decision
      # should only consider intents that actually failed or were not run.
      #
      # Uses connection_retries: 0 to disable individual retry in
      # ensure_result, making batch replay the only recovery path.
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_config = pool_config.configuration_hash.merge(connection_retries: 0)
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
        initial_pid = conn.select_value("SELECT pg_backend_pid()")

        conn.enter_pipeline_mode

        # Fast query, non-retryable - completes before the kill
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: false
        )
        # Slow query, retryable - server dies while processing
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n FROM pg_sleep(2)",
          name: "TEST",
          allow_retry: true
        )

        intent1.execute!
        intent2.execute!
        conn.pipeline_sync

        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # intent1 succeeded before the kill
        assert_equal [[1]], intent1.cast_result.rows

        # intent2 should recover via batch replay, not blocked by
        # intent1's allow_retry: false
        assert_equal [[2]], intent2.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_successful_intent_not_replayed_during_batch_recovery
      # When a retryable INSERT succeeds and is committed (via a
      # completed sync group), it must not be re-executed during batch
      # replay of a later failed intent. Replaying a committed write
      # would double-execute it.
      #
      # Setup: intent1 (INSERT) in sync group 1 - committed before the
      # kill. intent2 (slow SELECT) in sync group 2 - killed mid-flight.
      # Batch replay should recover intent2 without touching intent1.
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

        conn.execute("CREATE TABLE IF NOT EXISTS pipeline_replay_write_test (val int)")
        conn.execute("TRUNCATE pipeline_replay_write_test")

        initial_pid = conn.select_value("SELECT pg_backend_pid()")

        conn.enter_pipeline_mode

        # Sync group 1: retryable INSERT - fast, committed at sync point
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "INSERT INTO pipeline_replay_write_test VALUES (1)",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent1.execute!
        conn.pipeline_sync

        # Sync group 2: slow retryable query - server dies during sleep
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n FROM pg_sleep(2)",
          name: "TEST",
          allow_retry: true
        )
        intent2.execute!

        @connection.execute("SELECT pg_terminate_backend(#{initial_pid})")

        # intent2 recovers via batch replay
        assert_equal [[1]], intent2.cast_result.rows

        # intent1 already succeeded
        assert_equal 1, intent1.affected_rows

        # The INSERT was committed by sync group 1 and NOT replayed -
        # exactly one row, not two.
        count = conn.select_value("SELECT COUNT(*) FROM pipeline_replay_write_test")
        assert_equal 1, count

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        conn&.execute("DROP TABLE IF EXISTS pipeline_replay_write_test") rescue nil
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

        # Second query was server-aborted (never ran). It's resettable,
        # so on-demand re-execution succeeds (no enclosing transaction).
        result2 = intent2.cast_result
        assert_equal [[2]], result2.rows
      ensure
        lock_holder.execute("ROLLBACK") rescue nil
        test_pool.disconnect! rescue nil
      end
    end

    def test_abandon_distinguishes_synced_vs_unsynced_intents
      # Test the sync-aware partitioning logic in abandon_pipelined_intents.
      # Intents before a SyncIntent were synced (fate unknown), intents after
      # the last SyncIntent were never synced (safe to retry).

      # Simple stub that records which delivery method was called
      stub_intent = Class.new do
        attr_reader :delivered_failure, :not_run_reason

        def deliver_failure(error)
          @delivered_failure = error
        end

        def deliver_not_run(reason:, resettable: true)
          @not_run_reason = reason
        end
      end

      synced_intent = stub_intent.new
      unsynced_intent = stub_intent.new
      sync_marker = ActiveRecord::ConnectionAdapters::PostgreSQL::PipelineContext::SyncIntent.new

      # Simulate: [synced_intent, SyncIntent, unsynced_intent]
      # synced_intent is before the sync, unsynced_intent is after
      @connection.instance_variable_set(:@pending_intents, [synced_intent, sync_marker, unsynced_intent])

      @connection.send(:abandon_pipelined_intents)

      # Synced intent receives ConnectionFailed (fate unknown)
      assert_kind_of ActiveRecord::ConnectionFailed, synced_intent.delivered_failure
      assert_nil synced_intent.not_run_reason

      # Unsynced intent was definitely not run
      assert_nil unsynced_intent.delivered_failure
      assert_equal :unsynced, unsynced_intent.not_run_reason
    end

    def test_abandon_with_multiple_sync_markers
      # With multiple sync markers, all intents before the LAST sync marker
      # are considered synced (server may have executed). Only intents after
      # the last sync marker are unsynced.
      stub_intent = Class.new do
        attr_reader :delivered_failure, :not_run_reason

        def deliver_failure(error)
          @delivered_failure = error
        end

        def deliver_not_run(reason:, resettable: true)
          @not_run_reason = reason
        end
      end

      intent1 = stub_intent.new
      intent2 = stub_intent.new
      intent3 = stub_intent.new
      sync1 = ActiveRecord::ConnectionAdapters::PostgreSQL::PipelineContext::SyncIntent.new
      sync2 = ActiveRecord::ConnectionAdapters::PostgreSQL::PipelineContext::SyncIntent.new

      # [intent1, sync1, intent2, sync2, intent3]
      # intent1 and intent2 are before the last sync → synced
      # intent3 is after the last sync → unsynced
      @connection.instance_variable_set(:@pending_intents, [intent1, sync1, intent2, sync2, intent3])

      @connection.send(:abandon_pipelined_intents)

      assert_kind_of ActiveRecord::ConnectionFailed, intent1.delivered_failure
      assert_nil intent1.not_run_reason

      assert_kind_of ActiveRecord::ConnectionFailed, intent2.delivered_failure
      assert_nil intent2.not_run_reason

      assert_nil intent3.delivered_failure
      assert_equal :unsynced, intent3.not_run_reason
    end

    def test_synced_retryable_intents_replayed_after_connection_failure
      # Tests the "synced but retryable" replay path: queries that have
      # crossed a sync boundary (so the server may have executed them)
      # but are all marked allow_retry, so replay is still safe.
      #
      # This complements test_connection_failure_while_enqueuing which
      # tests the "unsynced" path (no sync boundary crossed, replay is
      # safe regardless of allow_retry).
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

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: true
        )

        intent1.execute!
        intent2.execute!

        # Sync the pipeline - this succeeds, recording a SyncIntent
        # marker. The server may have already processed the queries.
        conn.pipeline_sync

        # Now close the socket. The SyncIntent is already recorded,
        # so these intents are "synced" (fate unknown).
        raw_conn = conn.instance_variable_get(:@raw_connection)
        previous_stderr = $stderr
        begin
          $stderr = StringIO.new
          fd = raw_conn.socket
        ensure
          $stderr = previous_stderr
        end
        IO.for_fd(fd).close

        # Accessing results triggers flush_pipeline, which detects
        # the dead connection and replays because all synced intents
        # have allow_retry.
        assert_equal [[1]], intent1.cast_result.rows
        assert_equal [[2]], intent2.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_connection_failure_while_enqueuing_replays_unsynced_window
      # Tests that when the connection breaks after some queries have been
      # enqueued but before the pipeline is synced/flushed, all previously
      # queued intents are transparently replayed on a new connection.
      #
      # This is distinct from the drain-phase tests (like
      # test_multiple_retryable_pipelined_queries_all_recover) where the
      # connection dies while we're reading results. Here the connection
      # breaks while we're still writing queries into the pipeline.
      #
      # The setup: enqueue two queries, break the connection by closing
      # the underlying socket fd, then enqueue a third. The third enqueue
      # (or the subsequent flush) should detect the broken connection,
      # reconnect, and replay all three queries on the new connection.
      #
      # All intents use allow_retry: false to verify that replay works
      # based on the unsynced window status (no sync boundary was crossed,
      # so the server definitively did not execute any of these queries),
      # independent of the per-intent allow_retry flag.
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

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: false
        )

        intent1.execute!
        intent2.execute!

        # Close the underlying socket to simulate a connection break.
        raw_conn = conn.instance_variable_get(:@raw_connection)
        previous_stderr = $stderr
        begin
          $stderr = StringIO.new  # suppress libpq warnings about the fd
          fd = raw_conn.socket
        ensure
          $stderr = previous_stderr
        end
        IO.for_fd(fd).close

        # Enqueueing another query should trigger error detection,
        # reconnect, and replay the entire unsynced window.
        intent3 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 3 AS n",
          name: "TEST",
          allow_retry: false
        )
        intent3.execute!

        assert_equal [[1]], intent1.cast_result.rows
        assert conn.pipeline_active?
        assert_equal [[2]], intent2.cast_result.rows
        assert_equal [[3]], intent3.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_synced_non_retryable_intent_blocks_replay
      # When a synced intent is non-retryable, full replay is blocked.
      # The retryable intent recovers via individual retry; the
      # non-retryable one gets ConnectionFailed (fate unknown).
      #
      # Uses socket close for deterministic sync boundary placement,
      # unlike the pg_terminate_backend variant which is timing-dependent.
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

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: false  # blocks full replay
        )

        intent1.execute!
        intent2.execute!

        # Sync succeeds - both intents are now "synced"
        conn.pipeline_sync

        # Close socket after sync boundary is established
        raw_conn = conn.instance_variable_get(:@raw_connection)
        previous_stderr = $stderr
        begin
          $stderr = StringIO.new
          fd = raw_conn.socket
        ensure
          $stderr = previous_stderr
        end
        IO.for_fd(fd).close

        # intent1 is retryable - retries individually and succeeds
        assert_equal [[1]], intent1.cast_result.rows

        # intent2 was synced but not retryable - gets ConnectionFailed
        assert_raises(ActiveRecord::ConnectionFailed) do
          intent2.cast_result
        end

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_ensure_result_avoids_reconnect_storm
      # When a non-retryable synced intent blocks batch replay, retryable
      # intents fall back to individual retry in ensure_result. Without
      # the needs_reconnect? check, each retryable intent independently
      # calls reconnect!, tearing down the connection the previous intent
      # just established.
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

        reconnect_count = 0
        original_reconnect = conn.method(:reconnect!)
        conn.define_singleton_method(:reconnect!) do |**kwargs|
          reconnect_count += 1
          original_reconnect.call(**kwargs)
        end

        conn.enter_pipeline_mode

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: false,  # blocks batch replay
          materialize_transactions: false
        )
        intent3 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 3 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )

        intent1.execute!
        intent2.execute!
        intent3.execute!

        # Sync then close socket - all three intents are synced
        conn.pipeline_sync

        raw_conn = conn.instance_variable_get(:@raw_connection)
        previous_stderr = $stderr
        begin
          $stderr = StringIO.new
          fd = raw_conn.socket
        ensure
          $stderr = previous_stderr
        end
        IO.for_fd(fd).close

        # intent1 retries individually and reconnects
        assert_equal [[1]], intent1.cast_result.rows

        # intent2 is non-retryable - gets ConnectionFailed
        assert_raises(ActiveRecord::ConnectionFailed) { intent2.cast_result }

        # intent3 retries individually - should NOT reconnect again
        assert_equal [[3]], intent3.cast_result.rows

        new_pid = conn.select_value("SELECT pg_backend_pid()")
        assert_not_equal initial_pid, new_pid

        # The storm: without the fix, this is 2 (one per retryable intent).
        # With the fix, it should be 1.
        assert_equal 1, reconnect_count,
          "Expected a single reconnect, got #{reconnect_count} (reconnect storm)"
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_reconnectable_preserved_across_retry_in_ensure_result
      # When ensure_result retries a pipelined query via execute_intent,
      # the intent's @reconnectable flag must be preserved. The retry
      # loop sets @reconnectable = false after the first reconnect
      # attempt; initialize_retry_state's idempotent guard prevents
      # execute_intent from resetting it to true on re-execution.
      #
      # Without this, connection_retries: 2 would allow the retry loop
      # to reconnect twice (reconnect → fail → reconnect → fail) instead
      # of giving up after the first reconnect fails.
      pool_config = ActiveRecord::Base.connection_pool.db_config
      test_config = pool_config.configuration_hash.merge(connection_retries: 2)
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
        conn.connect!
        conn.materialize_transactions

        conn.enter_pipeline_mode

        # Non-retryable intent blocks batch replay in flush_pipeline,
        # forcing intent2 to retry individually in ensure_result
        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: false,
          materialize_transactions: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 2 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )

        intent1.execute!
        intent2.execute!
        conn.pipeline_sync

        # Close socket - both intents are synced, connection is dead
        raw_conn = conn.instance_variable_get(:@raw_connection)
        previous_stderr = $stderr
        begin
          $stderr = StringIO.new
          fd = raw_conn.socket
        ensure
          $stderr = previous_stderr
        end
        IO.for_fd(fd).close

        assert_raises(ActiveRecord::ConnectionFailed) { intent1.cast_result }

        # intent2 has a connection error from flush_pipeline's abandon.
        # Verify initial state: reconnectable is true (from pipeline
        # initialization), retries_remaining is 2.
        assert intent2.reconnectable, "Should start reconnectable"
        assert_equal 2, intent2.retries_remaining

        # Intercept execute_intent to simulate what it does - call
        # initialize_retry_state (the method under test) - then deliver
        # a connection error. This exercises whether the idempotent
        # guard preserves @reconnectable = false set by the retry loop.
        #
        # We cap at 5 invocations as a safety valve; without the
        # idempotent guard this would infinite-loop (retries_remaining
        # reset each time).
        original_execute_intent = conn.method(:execute_intent)
        reconnectable_after_init = []
        conn.define_singleton_method(:execute_intent) do |i|
          if i.equal?(intent2)
            # Simulate the initialize_retry_state call that execute_intent makes
            i.initialize_retry_state(
              retries: i.allow_retry ? connection_retries : 0,
              deadline: retry_deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) + retry_deadline,
              reconnectable: send(:reconnect_can_restore_state?)
            )
            reconnectable_after_init << i.reconnectable

            if reconnectable_after_init.size >= 5
              # Safety: break infinite loop by making intent non-retriable
              i.instance_variable_set(:@retries_remaining, 0)
            end

            i.deliver_failure(ActiveRecord::ConnectionFailed.new("Connection lost again"))
            return
          end
          original_execute_intent.call(i)
        end

        assert_raises(ActiveRecord::ConnectionFailed) do
          intent2.cast_result
        end

        # With the idempotent guard: execute_intent is called once,
        # @reconnectable stays false, classify_retry_action returns nil,
        # loop breaks. Without it: @reconnectable resets to true each
        # time, causing repeated reconnect attempts.
        assert_equal [false], reconnectable_after_init,
          "@reconnectable should be preserved as false across re-execution; " \
          "got #{reconnectable_after_init.inspect} (multiple calls = retry state leaked)"
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_flush_pipeline_stops_replaying_when_no_progress
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
        conn.connect!
        conn.materialize_transactions
        conn.enter_pipeline_mode

        self_destruct_sql = "SELECT pg_terminate_backend(pg_backend_pid()), pg_sleep(5)"

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: self_destruct_sql,
          name: "SELF_DESTRUCT",
          allow_retry: true,
          materialize_transactions: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "BYSTANDER",
          allow_retry: true,
          materialize_transactions: false
        )

        intent1.execute!
        intent2.execute!

        reconnect_count = 0
        conn.define_singleton_method(:reconnect!) do |**kwargs|
          super(**kwargs)
          reconnect_count += 1
        end

        conn.flush_pipeline

        assert_equal 1, reconnect_count,
          "Expected one replay attempt; without the progress check this would loop forever"
        assert intent1.raw_result_available?
        assert intent2.raw_result_available?
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_flush_pipeline_replays_successfully_after_transient_failure
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
        conn.connect!
        conn.materialize_transactions

        original_pid = conn.execute("SELECT pg_backend_pid() AS pid").first["pid"]
        conn.enter_pipeline_mode

        # Self-destructs on first run, but not after reconnect (PID changes).
        self_destruct_once_sql = "SELECT" \
          " CASE WHEN pg_backend_pid() = #{original_pid}" \
          " THEN pg_terminate_backend(pg_backend_pid()) ELSE true END," \
          " CASE WHEN pg_backend_pid() = #{original_pid}" \
          " THEN pg_sleep(5) END"

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: self_destruct_once_sql,
          name: "SELF_DESTRUCT_ONCE",
          allow_retry: true,
          materialize_transactions: false
        )
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "BYSTANDER",
          allow_retry: true,
          materialize_transactions: false
        )

        intent1.execute!
        intent2.execute!

        reconnect_count = 0
        conn.define_singleton_method(:reconnect!) do |**kwargs|
          super(**kwargs)
          reconnect_count += 1
        end

        conn.flush_pipeline

        assert_equal 1, reconnect_count
        assert intent1.raw_result_available?
        assert intent2.raw_result_available?
        assert_nil intent1.error
        assert_nil intent2.error
        assert_equal 1, intent2.raw_result.first["n"].to_i
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_unfinalized_intent_logs_closed_at_checkin
      # When pipelined intents are never accessed (ensure_result never
      # called), their sql.active_record notifications are started but
      # not finished. The checkin sweep should close them, recording
      # the appropriate final state - errors for failed intents, clean
      # close for not-run intents.
      events = []
      callback = ->(name, start, finish, id, payload) { events << payload }

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
        conn.connect!
        conn.materialize_transactions

        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          conn.enter_pipeline_mode

          intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
            adapter: conn,
            raw_sql: "SELECT * FROM nonexistent_table_xyz",
            name: "FAILED_UNCONSUMED"
          )
          intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
            adapter: conn,
            raw_sql: "SELECT 1 AS n",
            name: "ABORTED_UNCONSUMED"
          )

          intent1.execute!
          intent2.execute!

          conn.flush_pipeline

          # Neither intent is accessed - both have open logs
          assert intent1.log_handle, "Failed intent should have a log handle"
          assert_not intent1.finalized?, "Failed intent should not be finalized"
          assert intent2.log_handle, "Not-run intent should have a log handle"
          assert_not intent2.finalized?, "Not-run intent should not be finalized"

          # Check in triggers finalize_remaining_intents
          test_pool.checkin(conn)
        end

        # Failed intent's notification should record its error
        failed_event = events.find { |e| e[:name] == "FAILED_UNCONSUMED" }
        assert failed_event, "Failed intent notification should be finalized at checkin"
        assert failed_event[:exception], "Failed intent should be logged with its error"
        assert_match(/nonexistent_table_xyz/, failed_event[:exception].last)

        # Server-aborted intent's notification should record QueryNotRun.
        # Until the sweep, not_run is non-terminal (the caller might still
        # access the result, triggering re-execution). At sweep time, that
        # possibility is foreclosed and the log should reflect the failure.
        aborted_event = events.find { |e| e[:name] == "ABORTED_UNCONSUMED" }
        assert aborted_event, "Server-aborted intent notification should be finalized at checkin"
        assert aborted_event[:exception], "Not-run intent should be logged with QueryNotRun at sweep"
        assert_equal "ActiveRecord::QueryNotRun", aborted_event[:exception].first
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_server_aborted_query_reruns_on_demand_outside_transaction
      # When a SQL error aborts subsequent queries in a pipeline and
      # there's no enclosing transaction, the aborted queries can
      # re-execute on demand when their results are accessed.
      #
      # Uses a separate connection to avoid the fixture transaction,
      # which would leave the transaction in a failed state and block
      # re-execution.
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
        conn.connect!
        conn.materialize_transactions

        conn.enter_pipeline_mode

        intent1 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn, raw_sql: "SELECT 1 AS n", name: "TEST")
        intent2 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn, raw_sql: "SELECT * FROM nonexistent_table_xyz", name: "TEST")
        intent3 = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn, raw_sql: "SELECT 2 AS n", name: "TEST")

        intent1.execute!
        intent2.execute!
        intent3.execute!

        conn.flush_pipeline

        assert_equal [[1]], intent1.cast_result.rows
        assert_raises(ActiveRecord::StatementInvalid) { intent2.cast_result }

        # intent3 was server-aborted (never ran). Since there's no enclosing
        # transaction, on-demand re-execution succeeds.
        assert_equal :server_aborted, intent3.not_run_reason
        assert_equal [[2]], intent3.cast_result.rows
      ensure
        test_pool.disconnect! rescue nil
      end
    end

    def test_pipelined_intent_does_not_dirty_transaction_until_result_delivery
      with_dedicated_connection do |conn|
        with_rollback_transaction(conn) do
          conn.enter_pipeline_mode

          intent = build_intent(conn, "SELECT 1 AS n")
          intent.execute!

          assert_predicate conn.transaction_manager, :restorable?,
            "Queued-but-unrun pipelined intent should not dirty transaction state"

          assert_equal [[1]], intent.cast_result.rows

          assert_not_predicate conn.transaction_manager, :restorable?,
            "After result delivery, transaction should be dirty and non-restorable"
        end
      end
    end

    def test_unsynced_pipelined_queries_replay_in_clean_transaction
      with_dedicated_connection do |conn|
        initial_connection_id = connection_id_from_server(conn)

        with_rollback_transaction(conn) do
          conn.enter_pipeline_mode

          intent1 = build_intent(conn, "SELECT 1 AS n", allow_retry: false, materialize_transactions: false)
          intent2 = build_intent(conn, "SELECT 2 AS n", allow_retry: false, materialize_transactions: false)
          intent1.execute!
          intent2.execute!

          close_client_socket(conn)

          assert_equal [[1]], intent1.cast_result.rows
          assert_equal [[2]], intent2.cast_result.rows
          assert_connection_replaced(conn, initial_connection_id)
        end
      end
    end

    def test_synced_retryable_pipelined_queries_replay_in_clean_transaction
      with_dedicated_connection do |conn|
        initial_pid = connection_id_from_server(conn)

        with_rollback_transaction(conn) do
          conn.enter_pipeline_mode

          intent1 = build_intent(conn, "SELECT 1 AS n", allow_retry: true, materialize_transactions: false)
          intent2 = build_intent(conn, "SELECT 2 AS n", allow_retry: true, materialize_transactions: false)
          intent1.execute!
          intent2.execute!
          conn.pipeline_sync

          close_client_socket(conn)

          assert_equal [[1]], intent1.cast_result.rows
          assert_equal [[2]], intent2.cast_result.rows
          assert_connection_replaced(conn, initial_pid)
        end
      end
    end

    def test_synced_non_retryable_intent_fails_in_clean_transaction
      with_dedicated_connection do |conn|
        initial_pid = connection_id_from_server(conn)

        with_rollback_transaction(conn) do
          conn.enter_pipeline_mode

          retryable_intent = build_intent(conn, "SELECT 1 AS n", allow_retry: true, materialize_transactions: false)
          non_retryable_intent = build_intent(conn, "SELECT 2 AS n", allow_retry: false, materialize_transactions: false)
          retryable_intent.execute!
          non_retryable_intent.execute!
          conn.pipeline_sync

          close_client_socket(conn)

          assert_equal [[1]], retryable_intent.cast_result.rows
          assert_raises(ActiveRecord::ConnectionFailed) { non_retryable_intent.cast_result }
          assert_connection_replaced(conn, initial_pid)
        end
      end
    end

    def test_dirty_transaction_cannot_reconnect_during_pipeline_flush
      with_dedicated_connection do |conn|
        initial_connection_id = connection_id_from_server(conn)
        invocations = 0

        assert_raises(ActiveRecord::ConnectionFailed) do
          conn.transaction do
            invocations += 1

            conn.select_value("SELECT 0")
            assert_not_predicate conn.transaction_manager, :restorable?

            conn.enter_pipeline_mode
            intent = build_intent(conn, "SELECT 1 AS n FROM pg_sleep(2)", allow_retry: true)
            intent.execute!

            kill_connection_from_server(initial_connection_id, conn.pool)

            intent.cast_result
          end
        end

        assert_equal 1, invocations
        assert_not_predicate conn, :active?
        assert_equal 1, conn.select_value("SELECT 1")
      end
    end

    def test_dirty_transaction_cannot_reconnect_after_synced_pipeline_failure
      with_dedicated_connection do |conn|
        invocations = 0
        initial_connection_id = connection_id_from_server(conn)
        reconnect_count = 0
        original_reconnect = conn.method(:reconnect!)
        conn.define_singleton_method(:reconnect!) do |**kwargs|
          reconnect_count += 1
          original_reconnect.call(**kwargs)
        end

        assert_raises(ActiveRecord::ConnectionFailed) do
          conn.transaction do
            invocations += 1

            conn.select_value("SELECT 0")
            assert_not_predicate conn.transaction_manager, :restorable?

            conn.enter_pipeline_mode
            intent = build_intent(conn, "SELECT 1 AS n FROM pg_sleep(2)", allow_retry: true)
            intent.execute!
            conn.pipeline_sync

            kill_connection_from_server(initial_connection_id, conn.pool)
            intent.cast_result
          end
        end

        assert_equal 1, invocations
        assert_equal 0, reconnect_count
      end
    end

    def test_server_aborted_query_does_not_recover_inside_failed_transaction
      with_dedicated_connection do |conn|
        conn.transaction do
          conn.enter_pipeline_mode

          failing_intent = build_intent(conn, "SELECT * FROM nonexistent_table_xyz")
          aborted_intent = build_intent(conn, "SELECT 2 AS n")
          failing_intent.execute!
          aborted_intent.execute!

          conn.flush_pipeline

          assert_raises(ActiveRecord::StatementInvalid) { failing_intent.cast_result }
          assert_equal :server_aborted, aborted_intent.not_run_reason
          assert_raises(ActiveRecord::StatementInvalid) { aborted_intent.cast_result }

          raise ActiveRecord::Rollback
        end
      end
    end

    private
      def with_dedicated_connection(connection_retries: nil)
        pool_config = ActiveRecord::Base.connection_pool.db_config
        db_config =
          if connection_retries.nil?
            pool_config
          else
            ActiveRecord::DatabaseConfigurations::HashConfig.new(
              "test",
              "primary",
              pool_config.configuration_hash.merge(connection_retries: connection_retries)
            )
          end

        test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
          ActiveRecord::ConnectionAdapters::PoolConfig.new(
            ActiveRecord::Base,
            db_config,
            :writing,
            :default
          )
        )

        begin
          conn = test_pool.checkout
          conn.connect!
          conn.materialize_transactions
          yield conn
        ensure
          test_pool.disconnect! rescue nil
        end
      end

      def with_rollback_transaction(conn)
        conn.transaction do
          yield
          raise ActiveRecord::Rollback
        end
      end

      def build_intent(conn, sql, allow_retry: false, materialize_transactions: true)
        ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: sql,
          name: "TEST",
          allow_retry: allow_retry,
          materialize_transactions: materialize_transactions
        )
      end

      def assert_connection_replaced(conn, previous_pid)
        assert_not_equal previous_pid, connection_id_from_server(conn)
      end

      def close_client_socket(conn)
        raw_conn = conn.instance_variable_get(:@raw_connection)
        raw_conn.socket_io.close
      end
  end

  class PostgresqlPipelineDeferredReleaseTest < ActiveRecord::PostgreSQLTestCase
    self.use_transactional_tests = false

    def setup
      super
      @connection = ActiveRecord::Base.lease_connection
      pool_config = ActiveRecord::Base.connection_pool.db_config
      @test_pool = ActiveRecord::ConnectionAdapters::ConnectionPool.new(
        ActiveRecord::ConnectionAdapters::PoolConfig.new(
          ActiveRecord::Base,
          pool_config,
          :writing,
          :default
        )
      )
    end

    def teardown
      @test_pool.disconnect! rescue nil
      super
    end

    def test_connection_held_when_pipeline_pending
      # When a with_connection block exits while pipeline queries are
      # pending, the connection must stay leased (not returned to pool).
      intent = nil

      @test_pool.with_connection do |conn|
        conn.connect!
        conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!

        assert conn.pipeline_pending?, "Pipeline should have pending intents"
      end

      # Connection should still be in use - not returned to pool
      assert_equal 0, @test_pool.num_available_in_queue,
        "Connection should not be available in pool while pipeline is pending"

      conn = @test_pool.connections.first
      assert_predicate conn, :in_use?,
        "Connection should still be in use"
      assert conn.deferred_pool_release,
        "Connection should be marked for deferred release"

      # Clean up: access the result to drain pipeline, then release
      assert_equal [[1]], intent.cast_result.rows
    end

    def test_connection_released_when_subsequent_block_drains_pipeline
      # After a deferred release, entering a second with_connection that
      # drains the pipeline should release the connection on block exit.
      intent = nil

      @test_pool.with_connection do |conn|
        conn.connect!
        conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 42 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!
      end

      # Connection deferred - still in use
      conn = @test_pool.connections.first
      assert_predicate conn, :in_use?

      # Second block accesses the result, draining the pipeline
      @test_pool.with_connection do |conn2|
        assert_equal conn, conn2, "Should reuse the same connection"
        assert_equal [[42]], intent.cast_result.rows
        assert_not conn2.pipeline_pending?, "Pipeline should be drained"
      end

      # Now the connection should be released
      assert_not_predicate conn, :in_use?,
        "Connection should be released after pipeline drained in subsequent block"
    end

    def test_connection_released_when_pipeline_drains_outside_block
      # When the pipeline drains outside any with_connection block
      # (e.g., by accessing intent results directly), the connection
      # should be released via maybe_deferred_release.
      intent = nil

      @test_pool.with_connection do |conn|
        conn.connect!
        conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 99 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!
      end

      conn = @test_pool.connections.first
      assert_predicate conn, :in_use?

      # Access result outside any with_connection block - triggers
      # flush_pipeline → maybe_deferred_release
      assert_equal [[99]], intent.cast_result.rows

      assert_not_predicate conn, :in_use?,
        "Connection should be released after pipeline drains outside block"
    end

    def test_nested_with_connection_does_not_release_at_inner_exit
      # Pipeline drains in inner block, but connection should not be
      # released until the outer block exits.
      intent = nil

      @test_pool.with_connection do |outer_conn|
        outer_conn.connect!
        outer_conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: outer_conn,
          raw_sql: "SELECT 7 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!

        # Inner block drains the pipeline
        @test_pool.with_connection do |inner_conn|
          assert_equal outer_conn, inner_conn
          assert_equal [[7]], intent.cast_result.rows
          assert_not inner_conn.pipeline_pending?
        end

        # After inner block exits, connection should still be held
        # (depth > 0 at inner exit, but now we're back in outer)
        assert_predicate outer_conn, :in_use?,
          "Connection should NOT be released at inner block exit"
      end

      # After outer block exits, connection should be released
      conn = @test_pool.connections.first
      assert_not_predicate conn, :in_use?,
        "Connection should be released after outer block exits"
    end

    def test_request_end_flushes_and_releases_deferred_connection
      # Simulating request end: pool.release_connection should flush
      # the pipeline and return the connection to the pool.
      @test_pool.with_connection do |conn|
        conn.connect!
        conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!
      end

      conn = @test_pool.connections.first
      assert_predicate conn, :in_use?

      # release_connection is what ExecutorHooks.complete calls
      @test_pool.release_connection

      assert_not_predicate conn, :in_use?,
        "Connection should be released after release_connection"
    end

    def test_lease_connection_not_affected_by_deferred_release
      # lease_connection makes the lease sticky. Deferred release
      # logic should not interfere with sticky leases.
      conn = @test_pool.lease_connection
      conn.connect!

      @test_pool.with_connection do |wc_conn|
        assert_equal conn, wc_conn, "Should reuse leased connection"

        wc_conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: wc_conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!
      end

      # Connection should still be in use (sticky via lease_connection)
      assert_predicate conn, :in_use?,
        "Sticky connection should remain leased"

      # Clean up: drain pipeline and release
      conn.flush_pipeline
      conn.exit_pipeline_mode
      @test_pool.release_connection
    end

    def test_no_deferred_release_when_pipeline_not_pending
      # Normal case: when pipeline is not pending (or not active),
      # with_connection should release normally.
      @test_pool.with_connection do |conn|
        result = conn.select_value("SELECT 1")
        assert_equal 1, result
      end

      conn = @test_pool.connections.first
      assert_not_predicate conn, :in_use?,
        "Connection should be released normally when no pipeline is pending"
      assert_not conn.deferred_pool_release,
        "Deferred flag should not be set"
    end

    def test_deferred_release_does_not_make_connection_permanently_sticky
      # After pipeline drains and connection is released, a subsequent
      # with_connection should be able to check out and release normally.
      intent = nil

      @test_pool.with_connection do |conn|
        conn.connect!
        conn.enter_pipeline_mode

        intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(
          adapter: conn,
          raw_sql: "SELECT 1 AS n",
          name: "TEST",
          allow_retry: true,
          materialize_transactions: false
        )
        intent.execute!
      end

      # Drain outside block
      intent.cast_result

      conn = @test_pool.connections.first
      assert_not_predicate conn, :in_use?

      # A subsequent with_connection should check out and release normally
      @test_pool.with_connection do |conn2|
        conn2.select_value("SELECT 1")
      end

      assert_not_predicate conn, :in_use?,
        "Connection should not become permanently sticky after deferred release"
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
