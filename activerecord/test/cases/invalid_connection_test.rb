# frozen_string_literal: true

require "cases/helper"

class TestAdapterWithInvalidConnection < ActiveRecord::TestCase
  self.use_transactional_tests = false

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    class Bird < ActiveRecord::Base
    end

    def setup
      # Can't just use current adapter; sqlite3 will create a database
      # file on the fly.
      Bird.establish_connection adapter: ARTest.connection_name, database: "i_do_not_exist", host: "127.0.0.1", port: 12, username: "invalid"
    end

    teardown do
      Bird.remove_connection
    end

    test "inspect on Model class does not raise" do
      assert_equal "#{Bird.name} (call '#{Bird.name}.load_schema' to load schema informations)", Bird.inspect
    end
  end
end
