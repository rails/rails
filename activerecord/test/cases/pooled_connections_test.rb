require "cases/helper"

class PooledConnectionsTest < ActiveRecord::TestCase
  def setup
    super
    @connection = ActiveRecord::Base.remove_connection
  end

  def teardown
    ActiveRecord::Base.clear_all_connections!
    ActiveRecord::Base.establish_connection(@connection)
    super
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
end unless %w(FrontBase).include? ActiveRecord::Base.connection.adapter_name

class AllowConcurrencyDeprecatedTest < ActiveRecord::TestCase
  def test_allow_concurrency_is_deprecated
    assert_deprecated('ActiveRecord::Base.allow_concurrency') do
      ActiveRecord::Base.allow_concurrency
    end
    assert_deprecated('ActiveRecord::Base.allow_concurrency=') do
      ActiveRecord::Base.allow_concurrency = true
    end
  end
end
