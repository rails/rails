require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ReaperTest < ActiveRecord::TestCase
      attr_reader :pool

      def setup
        super
        @pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
      end

      def teardown
        super
        @pool.connections.each(&:close)
      end

      # A reaper with nil time should never reap connections
      def test_nil_time
        conn = pool.checkout
        pool.timeout = 0

        count = pool.connections.length
        conn.extend(Module.new { def active?; false; end; })

        reaper = ConnectionPool::Reaper.new(pool, nil)
        reaper.start
        sleep 0.0001
        assert_equal count, pool.connections.length
      end

      def test_some_time
        conn = pool.checkout
        pool.timeout = 0

        count = pool.connections.length
        conn.extend(Module.new { def active?; false; end; })

        reaper = ConnectionPool::Reaper.new(pool, 0.0001)
        reaper.start
        sleep 0.0002
        assert_equal(count - 1, pool.connections.length)
      end

      def test_pool_has_reaper
        assert pool.reaper
      end

      def test_reaping_frequency_configuration
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = 100
        pool = ConnectionPool.new spec
        assert_equal 100, pool.reaper.frequency
      end

      def test_connection_pool_starts_reaper
        spec = ActiveRecord::Base.connection_pool.spec.dup
        spec.config[:reaping_frequency] = 0.0001

        pool = ConnectionPool.new spec
        pool.timeout = 0

        conn = pool.checkout
        count = pool.connections.length

        conn.extend(Module.new { def active?; false; end; })

        sleep 0.0002
        assert_equal(count - 1, pool.connections.length)
      end
    end
  end
end
