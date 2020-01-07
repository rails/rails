# frozen_string_literal: true

require "cases/helper"

class TestRecord < ActiveRecord::Base
end

class TestDisconnectedAdapter < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection
  end

  teardown do
    return if in_memory_db?
    db_config = ActiveRecord::Base.connection_db_config
    ActiveRecord::Base.establish_connection(db_config)
  end

  unless in_memory_db?
    test "can't execute statements while disconnected" do
      @connection.execute "SELECT count(*) from products"
      @connection.disconnect!
      assert_raises(ActiveRecord::StatementInvalid) do
        silence_warnings do
          @connection.execute "SELECT count(*) from products"
        end
      end
    end
  end
end
