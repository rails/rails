# frozen_string_literal: true

require "cases/helper"
require "models/post"

class PipelinedQueriesTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  def setup
    super
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    @connection.exit_pipeline_mode if @connection.pipeline_active?
    super
  end

  def test_select_all
    future = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    assert_kind_of ActiveRecord::FutureResult, future
    assert_equal [{ "n" => 1 }], future.result.to_a
  end

  def test_select_one
    promise = @connection.select_one("SELECT 1 AS n, 2 AS m", "TEST", pipeline: true)
    assert promise.is_a?(ActiveRecord::Promise)
    assert_equal({ "n" => 1, "m" => 2 }, promise.value)
  end

  def test_select_value
    promise = @connection.select_value("SELECT 42", "TEST", pipeline: true)
    assert promise.is_a?(ActiveRecord::Promise)
    assert_equal 42, promise.value
  end

  def test_select_rows
    promise = @connection.select_rows("SELECT 1, 2 UNION ALL SELECT 3, 4", "TEST", pipeline: true)
    assert promise.is_a?(ActiveRecord::Promise)
    assert_equal [[1, 2], [3, 4]], promise.value
  end

  def test_then_chain
    promise = @connection.select_value("SELECT 7", "TEST", pipeline: true).then { |v| v * 6 }
    assert promise.is_a?(ActiveRecord::Promise)
    assert_equal 42, promise.value
  end

  def test_pending_before_result_access
    future = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    assert future.pending?

    future.result
    assert_not future.pending?
  end

  def test_multiple_queries_batch_together
    future1 = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    future2 = @connection.select_all("SELECT 2 AS n", "TEST", pipeline: true)

    assert future1.pending?
    assert future2.pending?
    assert @connection.pipeline_active?

    # Accessing the first result flushes all pending queries
    assert_equal [{ "n" => 1 }], future1.result.to_a
    assert_equal [{ "n" => 2 }], future2.result.to_a
  end

  def test_error_surfaces_on_result_access
    future = @connection.select_all("SELECT * FROM nonexistent_table_xyz", "TEST", pipeline: true)
    assert_kind_of ActiveRecord::FutureResult, future

    assert_raises(ActiveRecord::StatementInvalid) do
      future.result
    end
  end

  def test_works_inside_transaction
    # Unlike async, pipeline uses the same connection, so transactions work
    @connection.transaction do
      future = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
      assert_kind_of ActiveRecord::FutureResult, future
      assert_equal [{ "n" => 1 }], future.result.to_a
    end
  end

  def test_query_cache_hit_returns_complete
    @connection.enable_query_cache!

    # Prime the cache
    @connection.select_all("SELECT 1 AS n")

    # Cache hit with pipeline: true wraps the cached result
    result = @connection.select_all("SELECT 1 AS n", pipeline: true)
    assert_kind_of ActiveRecord::FutureResult::Complete, result
    assert_not result.pending?
    assert_equal [{ "n" => 1 }], result.result.to_a
  ensure
    @connection.disable_query_cache!
  end

  def test_mixed_select_methods_batch_together
    future = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    value  = @connection.select_value("SELECT 2", "TEST", pipeline: true)
    row    = @connection.select_one("SELECT 3 AS n", "TEST", pipeline: true)
    rows   = @connection.select_rows("SELECT 4, 5", "TEST", pipeline: true)

    assert future.pending?
    assert @connection.pipeline_active?

    assert_equal [{ "n" => 1 }], future.result.to_a
    assert_equal 2, value.value
    assert_equal({ "n" => 3 }, row.value)
    assert_equal [[4, 5]], rows.value
  end

  def test_accessing_later_result_first_flushes_all
    future1 = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    future2 = @connection.select_all("SELECT 2 AS n", "TEST", pipeline: true)

    # Access the second result first - should still flush everything
    assert_equal [{ "n" => 2 }], future2.result.to_a
    assert_not future1.pending?
    assert_equal [{ "n" => 1 }], future1.result.to_a
  end

  def test_synchronous_query_flushes_pending_pipeline
    future1 = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    future2 = @connection.select_all("SELECT 2 AS n", "TEST", pipeline: true)

    assert @connection.pipeline_active?

    # A non-pipelined query should flush the pipeline first
    sync_result = @connection.select_value("SELECT 3")
    assert_equal 3, sync_result

    # Pipeline results should now be available
    assert_not future1.pending?
    assert_not future2.pending?
    assert_equal [{ "n" => 1 }], future1.result.to_a
    assert_equal [{ "n" => 2 }], future2.result.to_a
  end

  def test_pipeline_then_synchronous_then_pipeline
    # First batch
    future1 = @connection.select_value("SELECT 1", "TEST", pipeline: true)
    future2 = @connection.select_value("SELECT 2", "TEST", pipeline: true)

    # Synchronous query flushes first batch
    sync = @connection.select_value("SELECT 3")
    assert_equal 3, sync
    assert_equal 1, future1.value
    assert_equal 2, future2.value

    # Second batch
    future3 = @connection.select_value("SELECT 4", "TEST", pipeline: true)
    future4 = @connection.select_value("SELECT 5", "TEST", pipeline: true)

    assert_equal 4, future3.value
    assert_equal 5, future4.value
  end

  def test_async_foreground_fallback_resolves_with_pipeline
    skip unless @connection.async_enabled?

    future1 = @connection.select_all("SELECT 1 AS n", "TEST", pipeline: true)
    future2 = @connection.select_all("SELECT 2 AS n", "TEST", pipeline: true)

    assert future1.pending?
    assert future2.pending?
    assert @connection.pipeline_active?

    # Stub the executor so the background thread never runs; the async query
    # will be enqueued but not executed until we access its result.
    async_future = @connection.pool.stub(:schedule_query, proc { }) do
      @connection.select_all("SELECT 3 AS n", "TEST", async: true)
    end

    # Enqueue should not have disturbed the pipeline
    assert @connection.pipeline_active?
    assert future1.pending?
    assert future2.pending?

    # Accessing the async result triggers execute_or_wait, which falls back
    # to the foreground on our (pipelined) connection, flushing everything.
    assert_equal [{ "n" => 3 }], async_future.result.to_a
    assert_equal [{ "n" => 1 }], future1.result.to_a
    assert_equal [{ "n" => 2 }], future2.result.to_a
  end

  def test_exclusion_checks_still_apply
    # Multi-statement SQL cannot be pipelined even with pipeline: true
    assert_raises(ArgumentError) do
      @connection.select_all("SELECT 1; SELECT 2", "TEST", pipeline: true)
    end
  end
end
