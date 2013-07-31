require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestDisconnectedAdapter < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    skip "in-memory database mustn't disconnect" if in_memory_db?
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    return if in_memory_db?
    spec = ActiveRecord::Base.connection_config
    ActiveRecord::Base.establish_connection(spec)
  end

  test "can't execute statements while disconnected" do
    @connection.execute "SELECT count(*) from products"
    @connection.disconnect!
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.execute "SELECT count(*) from products"
    end
  end
end
