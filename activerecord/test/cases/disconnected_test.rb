require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestDisconnectedAdapter < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    spec = ActiveRecord::Base.connection_config
    ActiveRecord::Base.establish_connection(spec)
    @connection = nil
  end

  test "can't execute statements while disconnected" do
    @connection.execute "SELECT count(*) from products"
    @connection.disconnect!
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.execute "SELECT count(*) from products"
    end
  end
end
