# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ReaperTest < ActiveRecord::TestCase
      attr_reader :pool

      def setup
        super
        @pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
      end

      teardown do
        @pool.connections.each(&:close)
      end

      class FakePool
        attr_reader :reaped
        attr_reader :flushed

        def initialize
          @reaped = false
        end

        def reap
          @reaped = true
        end

        def flush
          @flushed = true
        end
      end

      # A reaper with nil time should never reap connections
      def test_nil_time
        fp = FakePool.new
        assert_not fp.reaped
        reaper = ConnectionPool::Reaper.new(fp, nil)
        reaper.run
        assert_not fp.reaped
      end

      def test_some_time
        fp = FakePool.new
        assert_not fp.reaped

        reaper = ConnectionPool::Reaper.new(fp, 0.0001)
        reaper.run
        until fp.flushed
          Thread.pass
        end
        assert fp.reaped
        assert fp.flushed
      end

      def test_pool_has_reaper
        assert pool.reaper
      end

      def test_reaping_frequency_configuration
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "10.01"
        pool = ConnectionPool.new spec
        assert_equal 10.01, pool.reaper.frequency
      end

      def test_connection_pool_starts_reaper
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "0.0001"

        pool = ConnectionPool.new spec

        conn, child = new_conn_in_thread(pool)

        assert_predicate conn, :in_use?

        child.terminate

        wait_for_conn_idle(conn)
        assert_not_predicate conn, :in_use?
      end

      def test_reaper_works_after_pool_discard
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "0.0001"

        2.times do
          pool = ConnectionPool.new spec

          conn, child = new_conn_in_thread(pool)

          assert_predicate conn, :in_use?

          child.terminate

          wait_for_conn_idle(conn)
          assert_not_predicate conn, :in_use?

          pool.discard!
        end
      end

      # This doesn't test the reaper directly, but we want to test the action
      # it would take on a discarded pool
      def test_reap_flush_on_discarded_pool
        spec = ActiveRecord::Base.connection_pool.spec.dup
        pool = ConnectionPool.new spec

        pool.discard!
        pool.reap
        pool.flush
      end

      def test_connection_pool_starts_reaper_in_fork
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "0.0001"

        pool = ConnectionPool.new spec
        pool.checkout

        pid = fork do
          pool = ConnectionPool.new spec

          conn, child = new_conn_in_thread(pool)
          child.terminate

          wait_for_conn_idle(conn)
          if conn.in_use?
            exit!(1)
          else
            exit!(0)
          end
        end

        Process.waitpid(pid)
        assert $?.success?
      end

      def new_conn_in_thread(pool)
        event = Concurrent::Event.new
        conn = nil

        child = Thread.new do
          conn = pool.checkout
          event.set
          Thread.stop
        end

        event.wait
        [conn, child]
      end

      def wait_for_conn_idle(conn, timeout = 5)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        while conn.in_use? && Process.clock_gettime(Process::CLOCK_MONOTONIC) - start < timeout
          Thread.pass
        end
      end
    end
  end
end
