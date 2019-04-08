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
        @pool.shutdown!
      end

      class FakePool
        attr_reader :reaped
        attr_reader :flushed

        def initialize
          @reaped = false
          @shutting_down = false
        end

        def reap
          @reaped = true
        end

        def flush
          @flushed = true
        end

        def shutdown!
          @shutting_down = true
        end

        def shutting_down?
          @shutting_down
        end

        def spec
          nil
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
      ensure
        fp.shutdown! if fp
      end

      def test_pool_has_reaper
        assert pool.reaper
      end

      def test_reaping_frequency_configuration
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "10.01"
        pool = ConnectionPool.new spec
        assert_equal 10.01, pool.reaper.frequency
      ensure
        pool.shutdown! if pool
      end

      def test_connection_pool_starts_reaper
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = "0.0001"

        pool = ConnectionPool.new spec

        conn = nil
        child = Thread.new do
          conn = pool.checkout
          Thread.stop
        end
        Thread.pass while conn.nil?

        assert_predicate conn, :in_use?

        child.terminate

        while conn.in_use?
          Thread.pass
        end
        assert_not_predicate conn, :in_use?

      ensure
        pool.shutdown! if pool
      end
    end
  end
end
