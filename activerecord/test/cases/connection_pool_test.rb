require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPoolTest < ActiveRecord::TestCase
      def setup
        # Keep a duplicate pool so we do not bother others
        @pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec

        if in_memory_db?
          # Separate connections to an in-memory database create an entirely new database,
          # with an empty schema etc, so we just stub out this schema on the fly.
          @pool.with_connection do |connection|
            connection.create_table :posts do |t|
              t.integer :cololumn
            end
          end
        end
      end

      def test_active_connection?
        assert !@pool.active_connection?
        assert @pool.connection
        assert @pool.active_connection?
        @pool.release_connection
        assert !@pool.active_connection?
      end

      def test_pool_caches_columns
        columns = @pool.columns['posts']
        assert_equal columns, @pool.columns['posts']
      end

      def test_pool_caches_columns_hash
        columns_hash = @pool.columns_hash['posts']
        assert_equal columns_hash, @pool.columns_hash['posts']
      end

      def test_clearing_column_cache
        @pool.columns['posts']
        @pool.columns_hash['posts']

        @pool.clear_cache!

        assert_equal 0, @pool.columns.size
        assert_equal 0, @pool.columns_hash.size
      end

      def test_primary_key
        assert_equal 'id', @pool.primary_keys['posts']
      end

      def test_primary_key_for_non_existent_table
        assert_equal 'id', @pool.primary_keys['omgponies']
      end

      def test_primary_key_is_set_on_columns
        posts_columns = @pool.columns_hash['posts']
        assert posts_columns['id'].primary

        (posts_columns.keys - ['id']).each do |key|
          assert !posts_columns[key].primary
        end
      end

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

      def test_automatic_reconnect=
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
        assert pool.automatic_reconnect
        assert pool.connection

        pool.disconnect!
        assert pool.connection

        pool.disconnect!
        pool.automatic_reconnect = false

        assert_raises(ConnectionNotEstablished) do
          pool.connection
        end

        assert_raises(ConnectionNotEstablished) do
          pool.with_connection
        end
      end

      def test_pool_sets_connection_visitor
        assert @pool.connection.visitor.is_a?(Arel::Visitors::ToSql)
      end
    end
  end
end
