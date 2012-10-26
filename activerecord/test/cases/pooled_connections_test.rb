require "cases/helper"
require "models/project"
require "timeout"

class PooledConnectionsTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

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
    ActiveRecord::Base.establish_connection(@connection.merge({:pool => 2, :checkout_timeout => 0.3}))
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
  def checkout_checkin_connections(pool_size, threads)
    ActiveRecord::Base.establish_connection(@connection.merge({:pool => pool_size, :checkout_timeout => 0.5}))
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


  private

  def add_record(name)
    ActiveRecord::Base.connection_pool.with_connection { Project.create! :name => name }
  end
end unless current_adapter?(:FrontBase) || in_memory_db?
