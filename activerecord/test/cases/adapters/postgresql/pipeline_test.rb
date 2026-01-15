# frozen_string_literal: true

require "cases/helper"

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
      assert_not @connection.pipeline_active?, "Pipeline should not be active initially"

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
      assert_not @connection.pipeline_active?

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
