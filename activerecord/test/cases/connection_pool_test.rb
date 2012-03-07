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

          assert_deprecated do
            pool.connection
          end
          threads.each do |t|
            thread_ids = pool.instance_variable_get(:@reserved_connections).keys
            assert !thread_ids.include?(t.object_id)
          end
          pool.connection.close
        end.join

      end

      def test_threaded_with_connection
        # Neccesary to have a checked out connection in thread
        # other than one we will test, in order to trigger bug
        # we are testing fix for.
        main_thread_conn = ActiveRecord::Base.connection_pool.checkout

        aThread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.connection # need to do something AR to trigger the checkout

            reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)

            assert reserved_thread_ids.has_key?( Thread.current.object_id ), "thread should be in reserved connections"
          end
          reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
          assert !reserved_thread_ids.has_key?( Thread.current.object_id ), "thread should not be in reserved connections"
        end
        aThread.join

        ActiveRecord::Base.connection_pool.checkin main_thread_conn

        reserved_thread_ids = ActiveRecord::Base.connection_pool.instance_variable_get(:@reserved_connections)
        assert !reserved_thread_ids.has_key?( aThread.object_id ), "thread should not be in reserved connections"
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
