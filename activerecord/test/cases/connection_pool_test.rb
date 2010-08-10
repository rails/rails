require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPoolTest < ActiveRecord::TestCase
      def test_clear_stale_cached_connections!
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec

        threads = [
          Thread.new { pool.connection },
          Thread.new { pool.connection }]

        threads.map { |t| t.join }

        pool.extend Module.new {
          attr_accessor :checkins
          def checkin conn
            @checkins << conn
            conn.object_id
          end
        }
        pool.checkins = []

        cleared_threads = pool.clear_stale_cached_connections!
        assert((cleared_threads - threads.map { |x| x.object_id }).empty?,
               "threads should have been removed")
        assert_equal pool.checkins.length, threads.length
      end
    end
  end
end
