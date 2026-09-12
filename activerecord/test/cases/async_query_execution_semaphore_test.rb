# frozen_string_literal: true

require "cases/helper"
require "models/arunit2_model"
require "models/other_dog"
require "models/post"

module AsyncQueryExecutionSemaphoreHelpers
  private
    def with_semaphore(semaphore, &block)
      ActiveRecord::AsyncQueryExecutionSemaphore.send(:with_state, :active_record_async_query_execution_semaphore, semaphore, &block)
    end
end

class AsyncQueryExecutionSemaphoreTest < ActiveRecord::TestCase
  include AsyncQueryExecutionSemaphoreHelpers

  FakePool = Struct.new(:async_executor, :active_connection)

  def test_requires_a_positive_integer
    assert_raises(ArgumentError) { ActiveRecord.with_async_query_execution_limit(0) { } }
    assert_raises(ArgumentError) { ActiveRecord.with_async_query_execution_limit(-1) { } }
    assert_raises(ArgumentError) { ActiveRecord.with_async_query_execution_limit("2") { } }
    assert_raises(ArgumentError) { ActiveRecord.with_async_query_execution_limit(nil) { } }
  end

  def test_returns_the_block_value
    result = ActiveRecord.with_async_query_execution_limit(2) { :result }

    assert_equal :result, result
  end

  def test_nested_scopes_raise_without_changing_the_outer_semaphore
    ActiveRecord.with_async_query_execution_limit(2) do
      outer_semaphore = current_semaphore

      error = assert_raises(ArgumentError) do
        ActiveRecord.with_async_query_execution_limit(1) { flunk "block must not run" }
      end

      assert_equal "nested async query execution limits are not supported", error.message
      assert_same outer_semaphore, current_semaphore
    end

    assert_nil current_semaphore
  end

  def test_nil_raises_without_changing_an_enclosing_limit
    ActiveRecord.with_async_query_execution_limit(2) do
      outer_semaphore = current_semaphore

      assert_raises(ArgumentError) do
        ActiveRecord.with_async_query_execution_limit(nil) { flunk "block must not run" }
      end

      assert_same outer_semaphore, current_semaphore
    end
  end

  def test_restores_the_scope_when_the_block_raises
    assert_raises(RuntimeError) do
      ActiveRecord.with_async_query_execution_limit(1) { raise "boom" }
    end

    assert_nil current_semaphore
  end

  def test_the_scope_is_isolated_from_other_threads
    ActiveRecord.with_async_query_execution_limit(1) do
      semaphore_in_other_thread = Thread.new { current_semaphore }.value

      assert_nil semaphore_in_other_thread
      assert_not_nil current_semaphore
    end
  end

  def test_the_scope_is_isolated_from_other_fibers_when_fiber_isolation_is_enabled
    previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = :fiber

    ActiveRecord.with_async_query_execution_limit(1) do
      semaphore_in_other_fiber = Fiber.new { current_semaphore }.resume

      assert_nil semaphore_in_other_fiber
      assert_not_nil current_semaphore
    end
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous_isolation_level
  end

  def test_acquire_blocks_until_a_permit_is_released
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    first_permit = semaphore.acquire
    started = Queue.new
    acquired = Queue.new

    thread = Thread.new do
      started << true
      permit = semaphore.acquire
      acquired << true
      permit.release
    end

    started.pop
    assert_raises(ThreadError) { acquired.pop(true) }

    first_permit.release
    assert acquired.pop
    thread.join
  end

  def test_permit_can_only_be_released_once
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    permit = semaphore.acquire

    permit.release
    permit.release

    assert_equal 1, concurrent_semaphore(semaphore).available_permits
  end

  def test_reserve_releases_an_unclaimed_permit
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    pool = FakePool.new(Object.new, nil)

    with_semaphore(semaphore) { ActiveRecord::AsyncQueryExecutionSemaphore.reserve(pool) { } }

    assert_equal 1, concurrent_semaphore(semaphore).available_permits
  end

  def test_reserve_blocks_before_yielding
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    pool = FakePool.new(Object.new, nil)
    first_permit = semaphore.acquire
    started = Queue.new
    reserved = Queue.new

    thread = Thread.new do
      with_semaphore(semaphore) do
        started << true
        ActiveRecord::AsyncQueryExecutionSemaphore.reserve(pool) { reserved << true }
      end
    end

    started.pop
    assert_raises(ThreadError) { reserved.pop(true) }

    first_permit.release
    assert reserved.pop
    thread.join
  end

  def test_reserve_does_not_limit_calls_with_an_active_connection
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    pool = FakePool.new(Object.new, Object.new)
    permit = semaphore.acquire

    with_semaphore(semaphore) do
      result = ActiveRecord::AsyncQueryExecutionSemaphore.reserve(pool) { :result }
      assert_equal :result, result
    end
  ensure
    permit&.release
  end

  private
    def concurrent_semaphore(semaphore)
      semaphore.instance_variable_get(:@semaphore)
    end

    def current_semaphore
      ActiveRecord::AsyncQueryExecutionSemaphore.send(:current)
    end
end

class AsyncQueryExecutionLimitTest < ActiveRecord::TestCase
  include AsyncQueryExecutionSemaphoreHelpers

  self.use_transactional_tests = false

  class QueueingExecutor
    def initialize
      @jobs = Queue.new
    end

    def post(&job)
      @jobs << job
      true
    end

    def size
      @jobs.size
    end

    def run_next
      @jobs.pop.call
    end

    def run_all
      run_next until @jobs.empty?
    end
  end

  class NotifyingSemaphore < ActiveRecord::AsyncQueryExecutionSemaphore
    def initialize(limit)
      super
      @limit = limit
      @acquisitions = 0
      @mutex = Mutex.new
      @waiting = Queue.new
    end

    def acquire
      acquisition = @mutex.synchronize { @acquisitions += 1 }
      @waiting << true if acquisition > @limit
      super
    end

    def wait_until_blocked
      @waiting.pop
    end
  end

  class DiscardingExecutor
    def post
      false
    end
  end

  class QueueThenCallerRunsExecutor
    attr_reader :post_threads

    def initialize
      @jobs = Queue.new
      @post_threads = []
      @mutex = Mutex.new
      @posts = 0
    end

    def post(&job)
      post = @mutex.synchronize do
        @post_threads << Thread.current
        @posts += 1
      end

      if post == 1
        @jobs << job
      else
        job.call
      end
      true
    end

    def run_next
      @jobs.pop.call
    end
  end

  class RejectingExecutor
    def post
      raise Concurrent::RejectedExecutionError
    end
  end

  def test_async_query_calls_block_before_posting_past_the_limit
    skip if in_memory_db?

    with_async_executor(QueueingExecutor.new) do |executor|
      semaphore = NotifyingSemaphore.new(2)
      posted_before_release = Queue.new

      with_semaphore(semaphore) do
        count = Post.async_count
        ids = Post.limit(2).async_pluck(:id)
        runner = Thread.new do
          semaphore.wait_until_blocked
          posted_before_release << executor.size
          executor.run_next
        end

        posts = Post.limit(2).load_async
        runner.join

        assert_equal 2, posted_before_release.pop
        assert_equal 2, executor.size

        executor.run_all

        assert_equal Post.count, count.value
        assert_equal Post.limit(2).pluck(:id), ids.value
        assert_equal Post.limit(2).to_a, posts.to_a
      end
    end
  end

  def test_discarded_submission_releases_the_permit
    skip if in_memory_db?

    with_async_executor(DiscardingExecutor.new) do
      ActiveRecord.with_async_query_execution_limit(1) do
        first = Post.async_count
        second = Post.async_count

        assert_equal Post.count, first.value
        assert_equal Post.count, second.value
      end
    end
  end

  def test_caller_runs_executes_on_the_waiting_caller
    skip if in_memory_db?

    executor = QueueThenCallerRunsExecutor.new
    with_async_executor(executor) do
      semaphore = NotifyingSemaphore.new(1)
      caller = Thread.current

      with_semaphore(semaphore) do
        first = Post.async_count
        runner = Thread.new do
          semaphore.wait_until_blocked
          executor.run_next
        end

        second = Post.limit(2).async_pluck(:id)
        runner.join

        assert_same caller, executor.post_threads.second
        assert_equal Post.count, first.value
        assert_equal Post.limit(2).pluck(:id), second.value
      end
    end
  end

  def test_limit_is_shared_across_connection_pools
    skip if in_memory_db?

    primary_executor = QueueingExecutor.new
    secondary_executor = QueueingExecutor.new

    with_async_executors(
      ActiveRecord::Base.connection_pool => primary_executor,
      ARUnit2Model.connection_pool => secondary_executor,
    ) do
      semaphore = NotifyingSemaphore.new(1)
      posted_before_release = Queue.new

      with_semaphore(semaphore) do
        post_count = Post.async_count
        runner = Thread.new do
          semaphore.wait_until_blocked
          posted_before_release << [primary_executor.size, secondary_executor.size]
          primary_executor.run_next
        end

        dog_count = OtherDog.async_count
        runner.join

        assert_equal [1, 0], posted_before_release.pop
        assert_equal 1, secondary_executor.size

        secondary_executor.run_next

        assert_equal Post.count, post_count.value
        assert_equal OtherDog.count, dog_count.value
      end
    end
  end

  def test_rejected_submission_releases_the_permit
    skip if in_memory_db?

    with_async_executor(RejectingExecutor.new) do
      ActiveRecord.with_async_query_execution_limit(1) do
        assert_raises(Concurrent::RejectedExecutionError) { Post.async_count }
        assert_raises(Concurrent::RejectedExecutionError) { Post.async_count }
      end
    end
  end

  def test_disabled_executor_executes_without_waiting_for_a_permit
    semaphore = ActiveRecord::AsyncQueryExecutionSemaphore.new(1)
    permit = semaphore.acquire

    with_async_executor(nil) do
      with_semaphore(semaphore) do
        assert_equal Post.count, Post.async_count.value
      end
    end
  ensure
    permit&.release
  end

  private
    def with_async_executor(executor)
      pool = ActiveRecord::Base.connection_pool
      with_async_executors(pool => executor) { yield executor }
    end

    def with_async_executors(executors)
      original_executors = executors.to_h do |pool, executor|
        pool.release_connection
        original_executor = pool.async_executor
        pool.instance_variable_set(:@async_executor, executor)
        [pool, original_executor]
      end

      yield
    ensure
      original_executors&.each do |pool, executor|
        pool.instance_variable_set(:@async_executor, executor)
      end
    end
end
