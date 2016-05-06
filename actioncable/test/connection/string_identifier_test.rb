require 'test_helper'

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Connection < TestConnection
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end
  end

  test "connection identifier" do
    run_in_eventmachine do
      open_connection_with_stubbed_pubsub
      assert_equal "random-string", @connection.connection_identifier
    end
  end

  protected
    def open_connection_with_stubbed_pubsub
      @server = TestServer.new
      @server.stubs(:pubsub).returns(stub_everything('pubsub'))

      open_connection
    end

    def open_connection
      @connection = Connection.new(@server, default_env)

      @connection.process
      @connection.send :on_open
    end

    def close_connection
      @connection.send :on_close
    end
end
