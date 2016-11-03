require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::StringIdentifierTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    identified_by :current_token

    def connect
      self.current_token = "random-string"
    end

    def send_async(method, *args)
      send method, *args
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
      @server.stubs(:pubsub).returns(stub_everything("pubsub"))

      open_connection
    end

    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_HOST" => "localhost", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket"
      @connection = Connection.new(@server, env)

      @connection.process
      @connection.send :on_open
    end

    def close_connection
      @connection.send :on_close
    end
end
