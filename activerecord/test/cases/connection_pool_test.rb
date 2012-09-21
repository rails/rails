require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPoolTest < ActiveRecord::TestCase
      attr_reader :pool

      def setup
        super

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

      def teardown
        super
        @pool.disconnect!
      end

      def active_connections(pool)
        pool.connections.find_all(&:in_use?)
      end

      def test_checkout_after_close
        connection = pool.connection
        assert connection.in_use?

        connection.close
        assert !connection.in_use?

        assert pool.connection.in_use?
      end

      def test_released_connection_moves_between_threads
        thread_conn = nil

        Thread.new {
          pool.with_connection do |conn|
            thread_conn = conn
          end
        }.join

        assert thread_conn

        Thread.new {
          pool.with_connection do |conn|
            assert_equal thread_conn, conn
          end
        }.join
      end

      def test_with_connection
        assert_equal 0, active_connections(pool).size

        main_thread = pool.connection
        assert_equal 1, active_connections(pool).size

        Thread.new {
          pool.with_connection do |conn|
            assert conn
            assert_equal 2, active_connections(pool).size
          end
          assert_equal 1, active_connections(pool).size
        }.join

        main_thread.close
        assert_equal 0, active_connections(pool).size
      end

      def test_active_connection_in_use
        assert !pool.active_connection?
        main_thread = pool.connection

        assert pool.active_connection?

        main_thread.close

        assert !pool.active_connection?
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
      
      def test_timeout_spec_keys
        # 'wait_timeout' is supported for backwards compat, 
        # 'checkout_timeout' is preferred to avoid conflicting
        #  with mysql2 adapters key of name 'wait_timeout' but
        #  different meaning.
        config = ActiveRecord::Base.connection_pool.spec.config.merge(:wait_timeout => nil, :connection_timeout => nil)
        method = ActiveRecord::Base.connection_pool.spec.adapter_method        
        
        pool = ConnectionPool.new ActiveRecord::Base::ConnectionSpecification.new(config.merge(:wait_timeout => 1), method)
        assert_equal 1, pool.instance_variable_get(:@timeout)
        pool.disconnect!
        
        pool = ConnectionPool.new ActiveRecord::Base::ConnectionSpecification.new(config.merge(:checkout_timeout => 1), method)
        assert_equal 1, pool.instance_variable_get(:@timeout)
        pool.disconnect!
        
        pool = ConnectionPool.new ActiveRecord::Base::ConnectionSpecification.new(config.merge(:wait_timeout => 6000, :checkout_timeout => 1), method)
        assert_equal 1, pool.instance_variable_get(:@timeout)
        pool.disconnect!
      end
      
    end
  end
end
