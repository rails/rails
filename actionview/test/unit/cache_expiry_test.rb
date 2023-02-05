# frozen_string_literal: true

require "abstract_unit"

class ActionViewCacheExpiryTest < ActiveSupport::TestCase
  def test_execution_lock_can_be_acquired_and_released
    execution_lock = ActionView::CacheExpiry::ExecutionLock.new

    # It can acquire read lock:
    execution_lock.acquire_read_lock
    assert_equal 1, execution_lock.read_count
    execution_lock.release_read_lock
    assert_equal 0, execution_lock.read_count

    # It can acquire write lock:
    execution_lock.with_write_lock do
      assert_equal 1, execution_lock.write_count
    end
    assert_equal 0, execution_lock.write_count
  end

  def test_execution_lock_multiple_read_locks
    execution_lock = ActionView::CacheExpiry::ExecutionLock.new

    execution_lock.acquire_read_lock
    assert_equal 1, execution_lock.read_count

    execution_lock.acquire_read_lock
    assert_equal 2, execution_lock.read_count

    execution_lock.release_read_lock
    assert_equal 1, execution_lock.read_count

    execution_lock.release_read_lock
    assert_equal 0, execution_lock.read_count
  end

  def test_execution_lock_read_lock_upgraded_to_write_lock
    execution_lock = ActionView::CacheExpiry::ExecutionLock.new

    execution_lock.acquire_read_lock
    assert_equal 1, execution_lock.read_count

    execution_lock.with_write_lock do
      assert_equal 1, execution_lock.write_count
      assert_equal 1, execution_lock.read_count
    end

    assert_equal 1, execution_lock.read_count
    execution_lock.release_read_lock

    assert_equal 0, execution_lock.read_count
  end

  def test_execution_lock_write_lock_priority
    execution_lock = ActionView::CacheExpiry::ExecutionLock.new
    sequence = Thread::Queue.new

    execution_lock.acquire_read_lock
    assert_equal 1, execution_lock.read_count

    writer = Thread.new do
      execution_lock.acquire_read_lock

      execution_lock.with_write_lock do
        sequence << :write_lock_acquired
        assert_equal 1, execution_lock.write_count
        assert_equal 1, execution_lock.read_count
      end

      execution_lock.release_read_lock
    end

    reader = Thread.new do
      execution_lock.acquire_read_lock
      sequence << :read_lock_acquired
      assert_equal 1, execution_lock.read_count
      execution_lock.release_read_lock
      assert_equal 0, execution_lock.read_count
    end

    # Wait for both the threads to be waiting for the lock:
    Thread.pass until reader.status == "sleep" && writer.status == "sleep"

    # After releasing this read lock, the writer thread should take priority over the reader:
    execution_lock.release_read_lock
    assert_equal :write_lock_acquired, sequence.pop
    assert_equal :read_lock_acquired, sequence.pop

    reader.join
    writer.join

    assert_equal 0, execution_lock.read_count
    assert_equal 0, execution_lock.write_count
  end

  class EmptyWatcher
    def initialize(*)
    end

    def execute
    end

    def execute_if_updated
    end
  end

  def test_invoke_cache_expiry_on_different_threads
    executor = ActionView::CacheExpiry::Executor.new(watcher: EmptyWatcher)
    state = executor.run

    assert_nothing_raised do
      Thread.new do
        executor.complete(state)
      end.value
    end
  end

  def test_invoke_cache_expiry_on_different_fibers
    executor = ActionView::CacheExpiry::Executor.new(watcher: EmptyWatcher)
    state = executor.run

    assert_nothing_raised do
      Fiber.new do
        executor.complete(state)
      end.resume
    end
  end
end
