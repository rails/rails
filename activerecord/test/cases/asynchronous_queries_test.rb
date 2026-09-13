# frozen_string_literal: true

require "cases/helper"
require "models/post"

module AsynchronousQueriesSharedTests
  include ActiveRecord::TestCase::WaitForTestHelper

  def test_async_select_failure
    if in_memory_db?
      assert_raises ActiveRecord::StatementInvalid do
        @connection.select_all "SELECT * FROM does_not_exists", async: true
      end
    else
      future_result = @connection.select_all "SELECT * FROM does_not_exists", async: true
      assert_kind_of ActiveRecord::FutureResult, future_result
      assert_raises ActiveRecord::StatementInvalid do
        future_result.result
      end
    end
  end

  def test_async_query_from_transaction
    assert_nothing_raised do
      @connection.select_all "SELECT * FROM posts", async: true
    end

    unless in_memory_db?
      @connection.transaction do
        assert_raises ActiveRecord::AsynchronousQueryInsideTransactionError do
          @connection.select_all "SELECT * FROM posts", async: true
        end
      end
    end
  end

  def test_async_query_cache
    @connection.enable_query_cache!

    @connection.select_all "SELECT * FROM posts"
    result = @connection.select_all "SELECT * FROM posts", async: true
    assert_equal ActiveRecord::FutureResult::Complete, result.class
  ensure
    @connection.disable_query_cache!
  end

  def test_async_query_foreground_fallback
    events = capture_notifications("sql.active_record") do
      @connection.pool.stub(:schedule_query, proc { }) do
        if in_memory_db?
          assert_raises ActiveRecord::StatementInvalid do
            @connection.select_all "SELECT * FROM does_not_exists", async: true
          end
        else
          future_result = @connection.select_all "SELECT * FROM does_not_exists", async: true
          assert_kind_of ActiveRecord::FutureResult, future_result
          assert_raises ActiveRecord::StatementInvalid do
            future_result.result
          end
        end
      end
    end

    event = events.find { _1.payload[:sql] == "SELECT * FROM does_not_exists" }
    assert_not_nil event
    assert_equal false, event.payload[:async]
  end

  private
    def wait_for_future_result(result)
      wait_for(message: "future result still pending", timeout: 10, interval: 0.02) { !result.pending? }
    end
end

class AsynchronousQueriesTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  include AsynchronousQueriesSharedTests

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def test_async_select_all
    events = capture_notifications("sql.active_record") do
      future_result = @connection.select_all "SELECT * FROM posts", async: true

      if in_memory_db?
        assert_kind_of ActiveRecord::FutureResult::Complete, future_result
      else
        assert_kind_of ActiveRecord::FutureResult, future_result
        wait_for_future_result(future_result)
      end

      assert_kind_of ActiveRecord::Result, future_result.result
    end

    event = events.find { _1.payload[:sql] == "SELECT * FROM posts" }
    assert_not_nil event
    assert_equal @connection.supports_concurrent_connections?, event.payload[:async]
  end

  def test_async_query_retries_query_failure
    skip unless @connection.async_enabled?

    failure = ActiveRecord::LockWaitTimeout.new("lock wait timeout")
    matching = ->(intent) { intent.name == "Async Retry" }

    with_async_query_failures([failure], matching: matching) do |attempts|
      future_result = @connection.select_all(
        "SELECT 1 AS value", "Async Retry", async: true, allow_retry: true
      )
      wait_for_future_result(future_result)

      assert_equal 2, attempts.value
      assert_equal [[1]], future_result.result.rows
    end
  end

  def test_async_query_reports_failure_after_retries_are_exhausted
    skip unless @connection.async_enabled?
    skip unless @connection.connection_retries > 0

    failure = ActiveRecord::LockWaitTimeout.new("lock wait timeout")
    matching = ->(intent) { intent.name == "Async Retry Exhausted" }

    with_async_query_failures([failure], matching: matching, repeat_last: true) do |attempts|
      future_result = @connection.select_all(
        "SELECT 1 AS value", "Async Retry Exhausted", async: true, allow_retry: true
      )
      wait_for_async_query(@connection)

      assert_operator attempts.value, :>, 1
      error = assert_raises(ActiveRecord::LockWaitTimeout) { future_result.result }
      assert_equal "lock wait timeout", error.message
    end
  end

  def test_async_query_retries_connection_failure
    skip unless @connection.async_enabled?

    failure = ActiveRecord::ConnectionFailed.new("connection failed")
    matching = ->(intent) { intent.name == "Async Connection Retry" }

    with_async_query_failures([failure], matching: matching) do |attempts|
      future_result = @connection.select_all(
        "SELECT 1 AS value", "Async Connection Retry", async: true, allow_retry: true
      )
      wait_for_future_result(future_result)

      assert_equal 2, attempts.value
      assert_equal [[1]], future_result.result.rows
    end
  end

  def test_async_query_foreground_fallback_retries_query_failure
    skip unless @connection.async_enabled?

    failure = ActiveRecord::LockWaitTimeout.new("lock wait timeout")
    matching = ->(intent) { intent.name == "Async Fallback Retry" }

    with_async_query_failures([failure], matching: matching) do |attempts|
      @connection.pool.stub(:schedule_query, proc { }) do
        future_result = @connection.select_all(
          "SELECT 1 AS value", "Async Fallback Retry", async: true, allow_retry: true
        )

        assert_equal [[1]], future_result.result.rows
      end

      assert_equal 2, attempts.value
    end
  end

  def test_load_async_retries_query_failure
    skip unless @connection.async_enabled?

    failure = ActiveRecord::LockWaitTimeout.new("lock wait timeout")
    matching = ->(intent) { intent.name == "Post Load" }

    with_async_query_failures([failure], matching: matching) do |attempts|
      deferred_posts = Post.where(id: -1).load_async
      wait_for_async_query(@connection)

      assert_equal 2, attempts.value
      assert_empty deferred_posts.to_a
    end
  end

  private
    def with_async_query_failures(failures, matching:, repeat_last: false)
      adapter_class = @connection.class
      original_perform_query = adapter_class.instance_method(:perform_query)
      visibility = if adapter_class.private_instance_methods(false).include?(:perform_query)
        :private
      elsif adapter_class.protected_instance_methods(false).include?(:perform_query)
        :protected
      elsif adapter_class.instance_methods(false).include?(:perform_query)
        :public
      end
      attempts = Concurrent::AtomicFixnum.new

      adapter_class.send(:define_method, :perform_query) do |raw_connection, intent|
        if matching.call(intent)
          attempt = attempts.increment
          failure = failures[attempt - 1]
          failure ||= failures.last if repeat_last
          raise failure if failure
        end

        original_perform_query.bind_call(self, raw_connection, intent)
      end
      adapter_class.send(:private, :perform_query)

      yield attempts
    ensure
      if visibility
        adapter_class.send(:define_method, :perform_query, original_perform_query)
        adapter_class.send(visibility, :perform_query)
      else
        adapter_class.send(:remove_method, :perform_query)
      end
    end
end

class AsynchronousQueriesWithTransactionalTest < ActiveRecord::TestCase
  include AsynchronousQueriesSharedTests

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.materialize_transactions
  end
end

class AsynchronousExecutorTypeTest < ActiveRecord::TestCase
  def teardown
    clean_up_connection_handler
  end

  def test_null_configuration_uses_a_single_null_executor_by_default
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = nil

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
    db_config2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
    pool1 = handler.establish_connection(db_config)
    pool2 = handler.establish_connection(db_config2, owner_name: ARUnit2Model)

    async_pool1 = pool1.instance_variable_get(:@async_executor)
    async_pool2 = pool2.instance_variable_get(:@async_executor)

    assert_nil async_pool1
    assert_nil async_pool2

    assert_equal 2, handler.connection_pool_list(:all).count
  ensure
    ActiveRecord.async_query_executor = old_value
  end

  def test_one_global_thread_pool_is_used_when_set_with_default_concurrency
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = :global_thread_pool

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
    db_config2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
    pool1 = handler.establish_connection(db_config)
    pool2 = handler.establish_connection(db_config2, owner_name: ARUnit2Model)

    async_pool1 = pool1.instance_variable_get(:@async_executor)
    async_pool2 = pool2.instance_variable_get(:@async_executor)

    assert async_pool1.is_a?(Concurrent::ThreadPoolExecutor)
    assert async_pool2.is_a?(Concurrent::ThreadPoolExecutor)

    assert_equal 0, async_pool1.min_length
    assert_equal 4, async_pool1.max_length
    assert_equal 16, async_pool1.max_queue
    assert_equal :caller_runs, async_pool1.fallback_policy

    assert_equal 0, async_pool2.min_length
    assert_equal 4, async_pool2.max_length
    assert_equal 16, async_pool2.max_queue
    assert_equal :caller_runs, async_pool2.fallback_policy

    assert_equal 2, handler.connection_pool_list(:all).count
    assert_equal async_pool1, async_pool2
  ensure
    ActiveRecord.async_query_executor = old_value
  end

  def test_concurrency_can_be_set_on_global_thread_pool
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = :global_thread_pool
    old_concurrency = ActiveRecord.global_executor_concurrency
    old_global_thread_pool_async_query_executor = ActiveRecord.instance_variable_get(:@global_thread_pool_async_query_executor)
    ActiveRecord.instance_variable_set(:@global_thread_pool_async_query_executor, nil)
    ActiveRecord.global_executor_concurrency = 8

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
    db_config2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
    pool1 = handler.establish_connection(db_config)
    pool2 = handler.establish_connection(db_config2, owner_name: ARUnit2Model)

    async_pool1 = pool1.instance_variable_get(:@async_executor)
    async_pool2 = pool2.instance_variable_get(:@async_executor)

    assert async_pool1.is_a?(Concurrent::ThreadPoolExecutor)
    assert async_pool2.is_a?(Concurrent::ThreadPoolExecutor)

    assert_equal 0, async_pool1.min_length
    assert_equal 8, async_pool1.max_length
    assert_equal 32, async_pool1.max_queue
    assert_equal :caller_runs, async_pool1.fallback_policy

    assert_equal 0, async_pool2.min_length
    assert_equal 8, async_pool2.max_length
    assert_equal 32, async_pool2.max_queue
    assert_equal :caller_runs, async_pool2.fallback_policy

    assert_equal 2, handler.connection_pool_list(:all).count
    assert_equal async_pool1, async_pool2
  ensure
    ActiveRecord.global_executor_concurrency = old_concurrency
    ActiveRecord.async_query_executor = old_value
    ActiveRecord.instance_variable_set(:@global_thread_pool_async_query_executor, old_global_thread_pool_async_query_executor)
  end

  def test_concurrency_cannot_be_set_with_null_executor_or_multi_thread_pool
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = nil

    assert_raises ArgumentError do
      ActiveRecord.global_executor_concurrency = 8
    end

    ActiveRecord.async_query_executor = :multi_thread_pool

    assert_raises ArgumentError do
      ActiveRecord.global_executor_concurrency = 8
    end
  ensure
    ActiveRecord.async_query_executor = old_value
  end

  def test_multi_thread_pool_executor_configuration
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = :multi_thread_pool

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    config_hash = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").configuration_hash
    new_config_hash = config_hash.merge(min_threads: 0, max_threads: 10)
    db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", new_config_hash)
    db_config2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
    pool1 = handler.establish_connection(db_config)
    pool2 = handler.establish_connection(db_config2, owner_name: ARUnit2Model)

    async_pool1 = pool1.instance_variable_get(:@async_executor)
    async_pool2 = pool2.instance_variable_get(:@async_executor)

    assert async_pool1.is_a?(Concurrent::ThreadPoolExecutor)
    assert async_pool2.is_a?(Concurrent::ThreadPoolExecutor)

    assert_equal 0, async_pool1.min_length
    assert_equal 10, async_pool1.max_length
    assert_equal 40, async_pool1.max_queue
    assert_equal :caller_runs, async_pool1.fallback_policy

    assert_equal 0, async_pool2.min_length
    assert_equal 5, async_pool2.max_length
    assert_equal 20, async_pool2.max_queue
    assert_equal :caller_runs, async_pool2.fallback_policy

    assert_equal 2, handler.connection_pool_list(:all).count
    assert_not_equal async_pool1, async_pool2
  ensure
    ActiveRecord.async_query_executor = old_value
  end

  def test_multi_thread_pool_is_used_only_by_configurations_that_enable_it
    old_value = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = :multi_thread_pool

    handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

    config_hash1 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").configuration_hash
    new_config1 = config_hash1.merge(min_threads: 0, max_threads: 10)
    db_config1 = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", new_config1)

    config_hash2 = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary").configuration_hash
    new_config2 = config_hash2.merge(min_threads: 0, max_threads: 0)
    db_config2 = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit2", "primary", new_config2)

    pool1 = handler.establish_connection(db_config1)
    pool2 = handler.establish_connection(db_config2, owner_name: ARUnit2Model)

    async_pool1 = pool1.instance_variable_get(:@async_executor)
    async_pool2 = pool2.instance_variable_get(:@async_executor)

    assert async_pool1.is_a?(Concurrent::ThreadPoolExecutor)
    assert_nil async_pool2

    assert_equal 0, async_pool1.min_length
    assert_equal 10, async_pool1.max_length
    assert_equal 40, async_pool1.max_queue
    assert_equal :caller_runs, async_pool1.fallback_policy

    assert_equal 2, handler.connection_pool_list(:all).count
    assert_not_equal async_pool1, async_pool2
  ensure
    ActiveRecord.async_query_executor = old_value
  end
end
