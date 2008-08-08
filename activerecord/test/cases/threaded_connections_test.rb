require "cases/helper"
require 'models/topic'
require 'models/reply'

unless %w(FrontBase).include? ActiveRecord::Base.connection.adapter_name
  class ThreadedConnectionsTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    fixtures :topics

    def setup
      @connection = ActiveRecord::Base.remove_connection
      @connections = []
      @allow_concurrency = ActiveRecord::Base.allow_concurrency
      ActiveRecord::Base.allow_concurrency = true
    end

    def teardown
      # clear the connection cache
      ActiveRecord::Base.clear_active_connections!
      # set allow_concurrency to saved value
      ActiveRecord::Base.allow_concurrency = @allow_concurrency
      # reestablish old connection
      ActiveRecord::Base.establish_connection(@connection)
    end

    def gather_connections
      ActiveRecord::Base.establish_connection(@connection)

      5.times do
        Thread.new do
          Topic.find :first
          @connections << ActiveRecord::Base.active_connections.values.first
        end.join
      end
    end

    def test_threaded_connections
      gather_connections
      assert_equal @connections.length, 5
    end
  end

  class PooledConnectionsTest < ActiveRecord::TestCase
    def setup
      @connection = ActiveRecord::Base.remove_connection
      @allow_concurrency = ActiveRecord::Base.allow_concurrency
      ActiveRecord::Base.allow_concurrency = true
    end

    def teardown
      ActiveRecord::Base.clear_all_connections!
      ActiveRecord::Base.allow_concurrency = @allow_concurrency
      ActiveRecord::Base.establish_connection(@connection)
    end

    def checkout_connections
      ActiveRecord::Base.establish_connection(@connection.merge({:pool => 2, :wait_timeout => 0.3}))
      @connections = []
      @timed_out = 0

      4.times do
        Thread.new do
          begin
            @connections << ActiveRecord::Base.connection_pool.checkout
          rescue ActiveRecord::ConnectionTimeoutError
            @timed_out += 1
          end
        end.join
      end
    end

    def test_pooled_connection_checkout
      checkout_connections
      assert_equal @connections.length, 2
      assert_equal @timed_out, 2
    end

    def checkout_checkin_connections(pool_size, threads)
      ActiveRecord::Base.establish_connection(@connection.merge({:pool => pool_size, :wait_timeout => 0.5}))
      @connection_count = 0
      @timed_out = 0
      threads.times do
        Thread.new do
          begin
            conn = ActiveRecord::Base.connection_pool.checkout
            sleep 0.1
            ActiveRecord::Base.connection_pool.checkin conn
            @connection_count += 1
          rescue ActiveRecord::ConnectionTimeoutError
            @timed_out += 1
          end
        end.join
      end
    end

    def test_pooled_connection_checkin_one
      checkout_checkin_connections 1, 2
      assert_equal 2, @connection_count
      assert_equal 0, @timed_out
    end

    def test_pooled_connection_checkin_two
      checkout_checkin_connections 2, 3
      assert_equal 3, @connection_count
      assert_equal 0, @timed_out
    end

    def test_pooled_connection_checkout_existing_first
      ActiveRecord::Base.establish_connection(@connection.merge({:pool => 1}))
      conn_pool = ActiveRecord::Base.connection_pool
      conn = conn_pool.checkout
      conn_pool.checkin(conn)
      conn = conn_pool.checkout
      assert ActiveRecord::ConnectionAdapters::AbstractAdapter === conn
      conn_pool.checkin(conn)
    end
  end
end
