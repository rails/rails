# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/connection_pool"

class ConnectionPoolTest < ActiveSupport::TestCase
  Resource = Struct.new(:closed) do
    def close
      self.closed = true
    end
  end

  def test_nested_with_and_then_reuse_the_resource_and_release_after_an_exception
    pool = ActiveSupport::ConnectionPool.new(size: 1, timeout: 0) { Object.new }

    pool.with do |resource|
      assert_same resource, pool.then { |nested_resource| nested_resource }
    end

    assert_raises(RuntimeError) do
      pool.with { raise "failure" }
    end

    assert Thread.new { pool.with { |resource| resource } }.value
  end

  def test_checkout_times_out_when_another_thread_holds_the_only_resource
    pool = ActiveSupport::ConnectionPool.new(size: 1, timeout: 0) { Object.new }
    ready = Queue.new
    release = Queue.new

    holder = Thread.new do
      pool.with do
        ready << true
        release.pop
      end
    end

    ready.pop
    assert_raises(ActiveSupport::ConnectionPool::TimeoutError) { pool.checkout }
  ensure
    release << true if release && holder&.alive?
    holder&.join
  end

  def test_a_factory_error_does_not_consume_pool_capacity
    attempts = 0
    pool = ActiveSupport::ConnectionPool.new(size: 1, timeout: 0) do
      attempts += 1
      raise "failure" if attempts == 1

      Object.new
    end

    assert_raises(RuntimeError) { pool.checkout }
    assert pool.with { |resource| resource }
  end

  def test_negative_pool_size_is_invalid
    assert_raises(ArgumentError) do
      ActiveSupport::ConnectionPool.new(size: -1) { Object.new }
    end
  end

  def test_shutdown_rejects_checkout_with_an_internal_pool_error
    pool = ActiveSupport::ConnectionPool.new { Object.new }

    pool.shutdown(&:itself)

    error = assert_raises(ActiveSupport::ConnectionPool::PoolShuttingDownError) { pool.checkout }
    assert_kind_of ActiveSupport::ConnectionPool::Error, error
  end

  def test_reload_and_reap_replace_idle_resources
    resources = []
    pool = ActiveSupport::ConnectionPool.new(size: 1) { Resource.new.tap { |resource| resources << resource } }

    first = pool.with { |resource| resource }
    pool.reload(&:close)
    assert first.closed
    second = pool.with { |resource| resource }
    assert_not_same first, second

    pool.reap(idle_seconds: 0, &:close)
    assert second.closed
    assert_not_same second, pool.with { |resource| resource }
  end

  if Process.respond_to?(:fork)
    def test_fork_replaces_inherited_resources_in_the_child
      pool = ActiveSupport::ConnectionPool.new(size: 1) { Object.new }
      parent_resource = pool.checkout
      read, write = IO.pipe

      pid = Process.fork do
        read.close
        write.write(pool.with { |resource| (resource.object_id != parent_resource.object_id).to_s })
        write.close
        exit!
      end

      write.close
      Process.waitpid2(pid)
      assert_equal "true", read.read
      pool.checkin
      assert_same parent_resource, pool.with { |resource| resource }
    ensure
      read&.close unless read&.closed?
      write&.close unless write&.closed?
    end

  end
end
