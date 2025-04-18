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
        config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        pool_config = PoolConfig.new(ActiveRecord::Base, config, :writing, :default)
        pool = ConnectionPool.new(pool_config)

        assert pool.reaper
      ensure
        pool.discard!
      end

      def test_reaping_frequency_configuration
        pool_config = duplicated_pool_config(reaping_frequency: "10.01")
        pool = ConnectionPool.new(pool_config)

        assert_equal 10.01, pool.reaper.frequency
      ensure
        pool.discard!
      end

      def test_connection_pool_starts_reaper
        pool_config = duplicated_pool_config(reaping_frequency: "0.0001")
        pool = ConnectionPool.new(pool_config)

        conn, child = new_conn_in_thread(pool)

        assert_predicate conn, :in_use?

        child.terminate

        wait_for_conn_idle(conn)
        assert_not_predicate conn, :in_use?
      ensure
        pool.discard!
      end

      def test_reaper_works_after_pool_discard
        pool_config = duplicated_pool_config(reaping_frequency: "0.0001")

        2.times do
          pool = ConnectionPool.new(pool_config)

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
        pool_config = duplicated_pool_config
        pool = ConnectionPool.new(pool_config)

        pool.discard!
        assert_nothing_raised do
          pool.reap
          pool.flush
        end
      end

      if Process.respond_to?(:fork)
        def test_connection_pool_starts_reaper_in_fork
          pool_config = duplicated_pool_config(reaping_frequency: "0.0001")
          pool = ConnectionPool.new(pool_config)
          pool.checkout

          # We currently have a bug somewhere which leads for this test case to be deadlocked
          # and timeout after 30 minutes on the CI. Until that bug is fixed, this test is made
          # to timeout after a short period of time to reduce the damage.
          reader, writer = IO.pipe

          pid = fork do
            reader.close
            pool = ConnectionPool.new(pool_config)

            conn, child = new_conn_in_thread(pool)
            child.terminate

            wait_for_conn_idle(conn)
            writer.close
            if conn.in_use?
              exit!(1)
            else
              exit!(0)
            end
          end

          writer.close
          completed = reader.wait_readable(20)
          reader.close
          unless completed
            Process.kill("ABRT", pid)
          end
          _, status = Process.wait2(pid)
          assert_predicate status, :success?
        ensure
          pool.discard!
        end
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
        def duplicated_pool_config(merge_config_options = {})
          old_config = ActiveRecord::Base.connection_pool.db_config.configuration_hash.merge(merge_config_options)
          db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", old_config.dup)
          PoolConfig.new(ActiveRecord::Base, db_config, :writing, :default)
        end

        def new_conn_in_thread(pool)
          event = Concurrent::Event.new
          conn = nil

          child = Thread.new do
            conn = pool.checkout
            conn.query("SELECT 1") # ensure connected
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
