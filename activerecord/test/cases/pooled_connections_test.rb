require "cases/helper"
require "models/project"
require "timeout"

class PooledConnectionsTest < ActiveRecord::TestCase
  def setup
    @per_test_teardown = []
    @connection = ActiveRecord::Base.remove_connection
  end

  def teardown
    ActiveRecord::Base.clear_all_connections!
    ActiveRecord::Base.establish_connection(@connection)
    @per_test_teardown.each {|td| td.call }
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

  # Will deadlock due to lack of Monitor timeouts in 1.9
  if RUBY_VERSION < '1.9'
    def test_pooled_connection_checkout
      checkout_connections
      assert_equal 2, @connections.length
      assert_equal 2, @timed_out
    end
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
    assert_equal 1, ActiveRecord::Base.connection_pool.connections.size
  end

  def test_pooled_connection_checkin_two
    checkout_checkin_connections 2, 3
    assert_equal 3, @connection_count
    assert_equal 0, @timed_out
    assert_equal 1, ActiveRecord::Base.connection_pool.connections.size
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

  def test_not_connected_defined_connection_returns_false
    ActiveRecord::Base.establish_connection(@connection)
    assert ! ActiveRecord::Base.connected?
  end

  def test_undefined_connection_returns_false
    old_handler = ActiveRecord::Base.connection_handler
    ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    assert ! ActiveRecord::Base.connected?
  ensure
    ActiveRecord::Base.connection_handler = old_handler
  end

  def test_connection_config
    ActiveRecord::Base.establish_connection(@connection)
    assert_equal @connection, ActiveRecord::Base.connection_config
  end

  def test_with_connection_nesting_safety
    ActiveRecord::Base.establish_connection(@connection.merge({:pool => 1, :wait_timeout => 0.1}))

    before_count = Project.count

    add_record('one')

    ActiveRecord::Base.connection.transaction do
      add_record('two')
      # Have another thread try to screw up the transaction
      Thread.new do
        ActiveRecord::Base.connection.rollback_db_transaction
        ActiveRecord::Base.connection_pool.release_connection
      end
      add_record('three')
    end

    after_count = Project.count
    assert_equal 3, after_count - before_count
  end

  def test_connection_pool_callbacks
    checked_out, checked_in = false, false
    ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
      set_callback(:checkout, :after) { checked_out = true }
      set_callback(:checkin, :before) { checked_in = true }
    end
    @per_test_teardown << proc do
      ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
        reset_callbacks :checkout
        reset_callbacks :checkin
      end
    end
    checkout_checkin_connections 1, 1
    assert checked_out
    assert checked_in
  end

  private

  def add_record(name)
    ActiveRecord::Base.connection_pool.with_connection { Project.create! :name => name }
  end
end unless current_adapter?(:FrontBase) || in_memory_db?
