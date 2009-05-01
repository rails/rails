require "cases/helper"
require "models/project"
require "timeout"

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

  # Will deadlock due to lack of Monitor timeouts in 1.9
  if RUBY_VERSION < '1.9'
    def test_pooled_connection_checkout
      checkout_connections
      assert_equal @connections.length, 2
      assert_equal @timed_out, 2
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

  def test_not_connected_defined_connection_returns_false
    ActiveRecord::Base.establish_connection(@connection)
    assert ! ActiveRecord::Base.connected?
  end

  def test_undefined_connection_returns_false
    old_handler = ActiveRecord::Base.connection_handler
    ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    assert_equal false, ActiveRecord::Base.connected?
  ensure
    ActiveRecord::Base.connection_handler = old_handler
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
      end.join rescue nil
      add_record('three')
    end

    after_count = Project.count
    assert_equal 3, after_count - before_count
  end

  private

  def add_record(name)
    ActiveRecord::Base.connection_pool.with_connection { Project.create! :name => name }
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
