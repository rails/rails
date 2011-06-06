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

      def test_checkout_behaviour
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
        connection = pool.connection
        assert_not_nil connection
        threads = []
        4.times do |i|
          threads << Thread.new(i) do |pool_count|
            connection = pool.connection
            assert_not_nil connection
          end
        end
        
        threads.each {|t| t.join}
        
        Thread.new do
          threads.each do |t|
            thread_ids = pool.instance_variable_get(:@reserved_connections).keys
            assert thread_ids.include?(t.object_id)
          end

          pool.connection
          threads.each do |t|
            thread_ids = pool.instance_variable_get(:@reserved_connections).keys
            assert !thread_ids.include?(t.object_id)
          end
        end.join()

      end
    end
  end
end
