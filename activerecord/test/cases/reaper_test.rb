# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ReaperTest < ActiveRecord::TestCase
      class FakePool
        attr_reader :reaped
        attr_reader :flushed

        def initialize(discarded: false)
          @reaped = false
          @discarded = discarded
        end

        def reap
          @reaped = true
        end

        def flush
          @flushed = true
        end

        def discard!
          @discarded = true
        end

        def discarded?
          @discarded
        end
      end

      # A reaper with nil time should never reap connections
      def test_nil_time
        fp = FakePool.new
        assert_not fp.reaped
        reaper = ConnectionPool::Reaper.new(fp, nil)
        reaper.run
        assert_not fp.reaped
      ensure
        fp.discard!
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
      ensure
        fp.discard!
      end

      def test_pool_has_reaper
        config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", spec_name: "primary")
        spec = ConnectionSpecification.new("primary", config)
        pool = ConnectionPool.new spec

        assert pool.reaper
      ensure
        pool.discard!
      end

      def test_reaping_frequency_configuration
        spec = duplicated_spec
        spec.db_config.configuration_hash[:reaping_frequency] = "10.01"

        pool = ConnectionPool.new spec

        assert_equal 10.01, pool.reaper.frequency
      ensure
        pool.discard!
      end

      def test_connection_pool_starts_reaper
        spec = duplicated_spec
        spec.db_config.configuration_hash[:reaping_frequency] = "0.0001"

        pool = ConnectionPool.new spec

        conn, child = new_conn_in_thread(pool)

        assert_predicate conn, :in_use?

        child.terminate

        wait_for_conn_idle(conn)
        assert_not_predicate conn, :in_use?
      ensure
        pool.discard!
      end

      def test_reaper_works_after_pool_discard
        spec = duplicated_spec
        spec.db_config.configuration_hash[:reaping_frequency] = "0.0001"

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
        spec = duplicated_spec
        pool = ConnectionPool.new spec

        pool.discard!
        pool.reap
        pool.flush
      end

      def test_connection_pool_starts_reaper_in_fork
        spec = duplicated_spec
        spec.db_config.configuration_hash[:reaping_frequency] = "0.0001"

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
      ensure
        pool.discard!
      end

      def test_reaper_does_not_reap_discarded_connection_pools
        discarded_pool = FakePool.new(discarded: true)
        pool = FakePool.new
        frequency = 0.001

        ConnectionPool::Reaper.new(discarded_pool, frequency).run
        ConnectionPool::Reaper.new(pool, frequency).run

        until pool.flushed
          Thread.pass
        end

        assert_not discarded_pool.reaped
        assert pool.reaped
      ensure
        pool.discard!
      end

      private
        def duplicated_spec
          old_config = ActiveRecord::Base.connection_pool.spec.db_config.configuration_hash
          db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", old_config.dup)
          ConnectionSpecification.new("primary", db_config)
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
