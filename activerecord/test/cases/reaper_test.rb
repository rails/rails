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
        until fp.reaped
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
      end
    end
  end
end
